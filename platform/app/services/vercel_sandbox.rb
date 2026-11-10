# One throwaway Vercel Sandbox (a Firecracker microVM) to run commands in, driven through script/git_sandbox.mjs
# because the SDK is JavaScript only. GitRemote runs git here, so a repository server that manages to break git
# lands in an empty VM that can only reach that server, not in the worker next to every secret we have.
#
# Needs VERCEL_SANDBOX_TOKEN (a Vercel access token), VERCEL_SANDBOX_TEAM_ID and VERCEL_SANDBOX_PROJECT_ID;
# VERCEL_SANDBOX_REGION is optional (iad1 by default: where the control plane answers fastest and GitHub is). Slow (a VM boots, every command is a network
# round trip): call it from a job.
module VercelSandbox
  class Error < StandardError; end

  SCRIPT = Rails.root.join("script/git_sandbox.mjs").to_s
  CREDENTIALS = %w[VERCEL_SANDBOX_TOKEN VERCEL_SANDBOX_TEAM_ID VERCEL_SANDBOX_PROJECT_ID].freeze
  BOOT_TIMEOUT = 75
  # On top of a command's own time limit: the round trip and copying its output back.
  OVERHEAD = 30

  module_function

  def configured? = CREDENTIALS.all? { ENV[it].present? }

  # Yields a Session whose sandbox may only reach `host`. The sandbox is stopped and deleted when the block ends.
  def open(host)
    raise Error, "Vercel Sandbox isn't set up" unless configured?

    env = ENV.to_h.slice(*CREDENTIALS, "VERCEL_SANDBOX_REGION", "PATH")
    Open3.popen3(env, "node", SCRIPT, host, chdir: Rails.root.to_s, unsetenv_others: true, pgroup: true) do |stdin, stdout, stderr, wait|
      logs = Thread.new { stderr.read.to_s.last(4_000) }
      session = Session.new(stdin, stdout)
      begin
        ready = session.receive(BOOT_TIMEOUT)
        raise Error, "The sandbox didn't start: #{ready["error"]}" unless ready["ready"]

        session.dir = ready["dir"]
        yield session
      ensure
        stdin.close unless stdin.closed?
        unless wait.join(20)
          Process.kill("KILL", -wait.pid) rescue nil # rubocop:disable Style/RescueModifier
          wait.join
        end
        Rails.logger.warn("[vercel_sandbox] bridge exited #{wait.value.exitstatus.inspect}: #{logs.value}") unless wait.value.success?
      end
    end
  rescue Errno::ENOENT => e
    raise Error, "Couldn't start the sandbox bridge: #{e.message}"
  end

  class Session
    # An empty folder in the sandbox to work in.
    attr_accessor :dir

    def initialize(stdin, stdout)
      @stdin = stdin
      @stdout = stdout
      @buffer = +""
    end

    # Runs one command; returns [stdout (binary), stderr, whether it exited 0]. Raises Error when the sandbox
    # itself fails.
    def capture(env, command, dir, timeout:, max_file_bytes: nil)
      @stdin.puts({ cmd: command.first, args: command.drop(1), cwd: dir, env:, timeoutSeconds: timeout, maxFileBytes: max_file_bytes }.to_json)
      @stdin.flush
      reply = receive(timeout + OVERHEAD)
      raise Error, "The sandbox failed: #{reply["error"]}" if reply.key?("error")

      [ Base64.decode64(reply["stdout"].to_s), reply["stderr"].to_s, reply["exitCode"] == 0 ]
    rescue Errno::EPIPE, IOError
      raise Error, "The sandbox stopped"
    end

    # The next JSON line from the bridge, waiting at most `seconds`.
    def receive(seconds)
      deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + seconds
      until (newline = @buffer.index("\n"))
        left = deadline - Process.clock_gettime(Process::CLOCK_MONOTONIC)
        raise Error, "The sandbox took too long to answer" if left <= 0 || !@stdout.wait_readable(left)

        begin
          @buffer << @stdout.read_nonblock(1.megabyte)
        rescue IO::WaitReadable
          next
        rescue EOFError
          raise Error, "The sandbox stopped"
        end
      end
      JSON.parse(@buffer.slice!(0..newline))
    end
  end
end
