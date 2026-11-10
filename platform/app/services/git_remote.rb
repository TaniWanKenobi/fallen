# Reads a public git repository on any host that speaks smart HTTP (GitHub, GitLab, Codeberg, Forgejo, Gitea,
# sourcehut, Bitbucket, anyone's own server), for design submissions (RepoSnapshot). It is the only place that
# fetches a URL someone typed, so it assumes the URL and the server behind it are hostile:
#
# - https on port 443 only, a hostname (never an IP), no username or password in it.
# - The host is resolved here and refused if any address is private, loopback, link-local, shared, multicast or
#   otherwise not on the public internet. git is then pinned to the checked address (http.curloptResolve), so the
#   name can't be pointed somewhere else between the check and the fetch.
# - git runs with no inherited environment or config, no credential helpers or prompts, https as the only
#   protocol, no redirects, a time limit, a file size limit and a speed floor. Nothing is checked out, so no hook,
#   submodule, attribute or filter in the repo ever runs.
# - Only the file list comes over at first (a blobless, one-commit clone). The README and BOM are fetched one blob
#   at a time and refused past MAX_FILE_BYTES.
# - The review page's file viewers (read_files) get other files at the submitted commit, a few at a time, each
#   refused past MAX_BLOB_BYTES before it is read into memory.
module GitRemote
  class Error < StandardError; end

  MAX_URL_LENGTH = 300
  MAX_TREE_ENTRIES = 5_000
  MAX_FILE_BYTES = 512.kilobytes
  # The most one file read for the review page's viewers may be: room for CAD models, Gerber zips and datasheets.
  MAX_BLOB_BYTES = 25.megabytes
  # Files one read_files call may ask for, so one job can't be made to download a whole repository.
  MAX_FILES_PER_READ = 20
  COMMIT_SHA = /\A\h{40}(?:\h{24})?\z/
  TIMEOUT = 40
  # The most any one git process may write to disk, so a huge pack can't fill it.
  MAX_DISK_BYTES = 64.megabytes
  # Paths in a web page's URL that come after the repo itself (".../tree/main/pcb", ".../-/blob/...").
  WEB_SUFFIX = %r{/(?:-/|tree/|blob/|src/|commits?/|raw/|issues|pulls?/|merge_requests).*\z}
  README = /\Areadme(?:\.(?:md|markdown|mdx|txt|rst|adoc|org))?\z/i
  BOM = /(?:\A|[^a-z])(?:bom|bill[ _.-]?of[ _.-]?materials?)(?![a-z])[^\/]*\.csv\z/i
  BLOCKED_RANGES = %w[
    0.0.0.0/8 10.0.0.0/8 100.64.0.0/10 127.0.0.0/8 169.254.0.0/16 172.16.0.0/12 192.0.0.0/24 192.0.2.0/24
    192.88.99.0/24 192.168.0.0/16 198.18.0.0/15 198.51.100.0/24 203.0.113.0/24 224.0.0.0/4 240.0.0.0/4
    ::/128 ::1/128 ::ffff:0:0/96 64:ff9b::/96 64:ff9b:1::/48 100::/64 2001::/23 2001:db8::/32 2002::/16
    fc00::/7 fe80::/10 fec0::/10 ff00::/8
  ].map { |range| IPAddr.new(range) }.freeze

  Snapshot = Data.define(:url, :host, :branch, :commit_sha, :tree, :tree_truncated, :readme_path, :readme, :bom_path, :bom_csv)

  module_function

  # The repo's own URL from what someone pasted, or raises Error with a message for them.
  def normalize(input)
    text = input.to_s.strip
    raise Error, "Paste your repository's link" if text.empty?
    raise Error, "That link is too long" if text.length > MAX_URL_LENGTH

    text = "https://#{text}" unless text.include?("://")
    uri = URI.parse(text)
    raise Error, "Use your repository's https:// link (not ssh or git://)" unless uri.is_a?(URI::HTTPS)
    raise Error, "Take the username or password out of the link" if uri.userinfo
    raise Error, "Only repositories on the standard https port (443) can be read" unless uri.port == 443
    raise Error, "Remove the ?query or #part from the link" if uri.query || uri.fragment

    host = uri.host.to_s.downcase.delete_suffix(".")
    raise Error, "Use the repository's web address, not an IP address" if ip_literal?(host)
    raise Error, "That doesn't look like a public website" unless host.include?(".") && host.match?(/\A[a-z0-9.-]+\z/) && !host.end_with?(".local", ".internal", ".localhost")

    path = uri.path.sub(WEB_SUFFIX, "").chomp("/")
    raise Error, "Link to the repository itself, like https://github.com/you/project" if path.count("/") < 2 || path.include?("..")

    "https://#{host}#{path}"
  rescue URI::InvalidURIError
    raise Error, "That isn't a link"
  end

  # The repository as it is now on its default branch. Slow (a network fetch): call it from a job.
  def snapshot(input)
    url = normalize(input)
    host = URI.parse(url).host
    address = public_address(host)

    Dir.mktmpdir("repo") do |dir|
      git = ->(*args, **opts, &on_error) { run(dir, host, address, *args, **opts, &on_error) }
      clone(git, url)
      repo = File.join(dir, "repo.git")
      branch = git.call("symbolic-ref", "--short", "HEAD", repo:).strip
      sha = git.call("rev-parse", "HEAD", repo:).strip
      tree, truncated, oids = list_tree(git.call("ls-tree", "-r", "-t", "--full-tree", "-z", "HEAD", repo:))
      readme_path = pick(tree, README)
      bom_path = pick(tree, BOM)
      files = read_blobs(git, repo, [ readme_path, bom_path ].compact.map { |path| oids[path] })

      Snapshot.new(url:, host:, branch:, commit_sha: sha, tree:, tree_truncated: truncated, readme_path:,
        readme: readme_path && files[oids[readme_path]], bom_path:, bom_csv: bom_path && files[oids[bom_path]])
    end
  end

  # Files of the repository as they are at `commit_sha`, by path: each one's bytes (binary), or an Error saying why
  # that file couldn't be read (not in the commit, too big, refused by the server). Raises Error when the repository
  # or the commit can't be read at all. Slow (a network fetch): call it from a job.
  def read_files(input, commit_sha, paths, limit: MAX_BLOB_BYTES)
    url = normalize(input)
    raise Error, "That isn't a commit" unless commit_sha.to_s.match?(COMMIT_SHA)

    paths = paths.map(&:to_s).uniq
    raise Error, "Ask for at most #{MAX_FILES_PER_READ} files at once" if paths.size > MAX_FILES_PER_READ
    return {} if paths.empty?

    host = URI.parse(url).host
    address = public_address(host)
    Dir.mktmpdir("repo") do |dir|
      git = ->(*args, **opts, &on_error) { run(dir, host, address, *args, **opts, &on_error) }
      repo = File.join(dir, "repo.git")
      git.call("init", "--quiet", "--bare", repo)
      fetch_commit(git, repo, url, commit_sha)
      files_at(git, repo, commit_sha, paths, limit:)
    end
  end

  # The one address git may connect to, after every address the name has was checked.
  def public_address(host)
    addresses = Resolv.getaddresses(host).filter_map { |a| IPAddr.new(a) rescue nil } # rubocop:disable Style/RescueModifier
    raise Error, "Couldn't find #{host}" if addresses.empty?
    raise Error, "#{host} isn't on the public internet" unless addresses.all? { |a| public_ip?(a) }

    addresses.find(&:ipv4?) || addresses.first
  end

  def public_ip?(address) = BLOCKED_RANGES.none? { |range| range.family == address.family && range.include?(address) }

  def ip_literal?(host)
    host.start_with?("[") || IPAddr.new(host).present?
  rescue IPAddr::InvalidAddressError
    false
  end

  # A link to one file at the commit, for the hosts whose web pages we know, or nil.
  def file_url(url, commit_sha, path)
    host = URI.parse(url).host
    case host
    when "github.com" then "#{url}/blob/#{commit_sha}/#{path}"
    when "gitlab.com" then "#{url}/-/blob/#{commit_sha}/#{path}"
    when "codeberg.org" then "#{url}/src/commit/#{commit_sha}/#{path}"
    when "bitbucket.org" then "#{url}/src/#{commit_sha}/#{path}"
    when "git.sr.ht" then "#{url}/tree/#{commit_sha}/item/#{path}"
    end
  end

  # Runs one git command with nothing from this machine's environment or config. Yields stderr on failure, or
  # raises Error.
  def run(dir, host, address, *args, repo: nil)
    pin = "#{host}:443:#{address.ipv6? ? "[#{address}]" : address}"
    command = [
      "git",
      "-c", "protocol.allow=never", "-c", "protocol.https.allow=always",
      "-c", "http.followRedirects=false", "-c", "http.curloptResolve=#{pin}",
      "-c", "http.lowSpeedLimit=1000", "-c", "http.lowSpeedTime=15",
      "-c", "credential.helper=", "-c", "core.askPass=", "-c", "core.hooksPath=/dev/null",
      "-c", "core.symlinks=false", "-c", "submodule.recurse=false", "-c", "fetch.recurseSubmodules=false",
      "-c", "transfer.fsckObjects=true",
      *(repo ? [ "--git-dir=#{repo}" ] : []),
      *args
    ]
    env = {
      "PATH" => "/usr/local/bin:/usr/bin:/bin", "HOME" => dir, "GIT_CONFIG_NOSYSTEM" => "1",
      "GIT_CONFIG_GLOBAL" => "/dev/null", "GIT_TERMINAL_PROMPT" => "0", "GIT_ASKPASS" => "/bin/false",
      "SSH_ASKPASS" => "/bin/false", "GIT_PROTOCOL_FROM_USER" => "0", "LC_ALL" => "C"
    }
    out, err, status = capture(env, command, dir)
    return out if status&.success?

    block_given? ? yield(err.to_s) : raise(Error, "The repository couldn't be read")
  end

  def capture(env, command, dir)
    stdout, stderr, status = nil
    Open3.popen3(env, *command, chdir: dir, unsetenv_others: true, pgroup: true, rlimit_fsize: MAX_DISK_BYTES) do |stdin, out, err, wait|
      stdin.close
      readers = [ Thread.new { out.read }, Thread.new { err.read } ]
      unless wait.join(TIMEOUT)
        Process.kill("KILL", -wait.pid) rescue nil # rubocop:disable Style/RescueModifier
        wait.join
        raise Error, "The repository took too long to read"
      end
      stdout, stderr = readers.map(&:value)
      status = wait.value
    end
    [ stdout, stderr, status ]
  rescue SystemCallError => e
    # git missing or unrunnable is our fault, not the repo's: report it, and still fail the read so nobody waits on
    # a check that never finishes.
    Rails.error.report(e, handled: true)
    raise Error, "We couldn't read repositories just now. Try again in a bit."
  end

  def clone_error(stderr)
    case stderr
    when /not found|does not exist|404/i, /could not read Username|Authentication failed|403|401/i
      "Couldn't find a public repository there. Is it public, and is the link right?"
    when ->(text) { redirected?(text) } then "That link redirects somewhere else. Paste the repository's own link."
    when /timed out|too slow|Operation too slow/i then "The repository took too long to read"
    when /File size limit|too large/i then "The repository is too big to read"
    else "Couldn't read a git repository at that link"
    end
  end

  # [{ "path" => "pcb/board.kicad_pcb", "type" => "blob" }, ...] from `ls-tree -z`, whether it was cut short, and
  # each file's object id by path.
  def list_tree(output)
    oids = {}
    entries = output.split("\0").filter_map do |line|
      meta, path = line.split("\t", 2)
      next if path.blank?

      _mode, type, oid = meta.split(" ")
      path = path.scrub
      oids[path] = oid if type == "blob"
      { "path" => path, "type" => type }
    end
    [ entries.first(MAX_TREE_ENTRIES), entries.size > MAX_TREE_ENTRIES, oids ]
  end

  # The shallowest file whose name matches, so a README at the root wins over one in a library folder.
  def pick(tree, pattern)
    tree.select { |entry| entry["type"] == "blob" && File.basename(entry["path"]).match?(pattern) }
      .min_by { |entry| [ entry["path"].count("/"), entry["path"].length ] }&.dig("path")
  end

  def redirected?(stderr) = stderr.match?(/redirect|error: 30[12378]\b/i)

  # Some hosts only answer at the ".git" address and redirect the bare one, and redirects are never followed.
  def clone(git, url)
    error = nil
    [ url, "#{url}.git" ].each do |attempt|
      failed = false
      git.call("clone", "--quiet", "--bare", "--depth=1", "--filter=blob:none", "--single-branch", "--no-tags", "--", attempt, "repo.git") { |stderr| failed = true; error = stderr }
      return unless failed
      break unless redirected?(error)
    end
    raise Error, clone_error(error)
  end

  # Just the commit's trees, with the same ".git" retry as clone.
  def fetch_commit(git, repo, url, sha)
    error = nil
    [ url, "#{url}.git" ].each_with_index do |attempt, i|
      git.call("remote", i.zero? ? "add" : "set-url", "origin", attempt, repo:)
      failed = false
      git.call("fetch", "--quiet", "--no-tags", "--no-write-fetch-head", "--recurse-submodules=no", "--depth=1", "--filter=blob:none", "origin", sha, repo:) { |stderr| failed = true; error = stderr }
      return unless failed
      break unless redirected?(error)
    end
    raise Error, error.to_s.match?(/not our ref|unadvertised|no such remote ref|couldn't find remote ref/i) ? "That commit isn't in the repository any more" : clone_error(error)
  end

  # Each path's bytes at the commit. The blobs come in one fetch; when that fails (one of them is too big, say) each
  # is fetched alone, so only the bad one fails.
  def files_at(git, repo, sha, paths, limit:)
    _tree, _truncated, oids = list_tree(git.call("ls-tree", "-r", "-z", "--full-tree", sha, repo:))
    wanted = paths.filter_map { |path| oids[path] }.uniq
    fetch_blobs(git, repo, wanted) { nil } if wanted.any?
    paths.index_with do |path|
      oid = oids[path]
      next Error.new("That file isn't in this commit") unless oid

      read_blob(git, repo, oid, limit:)
    end
  end

  def read_blob(git, repo, oid, limit:)
    unless git.call("--no-lazy-fetch", "cat-file", "-e", oid, repo:) { nil }
      fetch_blobs(git, repo, [ oid ]) { return Error.new("The server wouldn't send this file, or it's too big") }
    end
    size = git.call("--no-lazy-fetch", "cat-file", "-s", oid, repo:).to_i
    return Error.new("This file is over #{ActiveSupport::NumberHelper.number_to_human_size(limit)}, too big to show here") if size > limit

    git.call("--no-lazy-fetch", "cat-file", "blob", oid, repo:).b
  end

  def fetch_blobs(git, repo, oids, &on_error)
    git.call("-c", "fetch.negotiationAlgorithm=noop", "fetch", "--quiet", "--no-tags", "--no-write-fetch-head", "--recurse-submodules=no", "--filter=blob:none", "origin", *oids, repo:, &on_error)
  end

  # The files' text by object id, in one fetch. Servers send a blob asked for by id whatever its size, so a huge
  # one is stopped by MAX_DISK_BYTES and the text is cut at MAX_FILE_BYTES.
  def read_blobs(git, repo, oids)
    return {} if oids.empty?

    fetch_blobs(git, repo, oids) { return {} }
    oids.index_with do |oid|
      present = git.call("--no-lazy-fetch", "cat-file", "-e", oid, repo:) { nil }
      present && git.call("--no-lazy-fetch", "cat-file", "blob", oid, repo:).byteslice(0, MAX_FILE_BYTES).force_encoding(Encoding::UTF_8).scrub
    end
  end
end
