require "test_helper"

class VercelSandboxTest < ActiveSupport::TestCase
  test "runs a command through the bridge and gets its stdout back byte for byte" do
    with_bridge(->(request) { { exitCode: 0, stdout: Base64.strict_encode64("\xFF\x00#{request["args"].join}".b), stderr: "warn" } }) do |session|
      out, err, ok = session.capture({ "HOME" => "/tmp/repo" }, %w[git cat-file blob abc], "/tmp/repo", timeout: 5)

      assert ok
      assert_equal "\xFF\x00cat-fileblobabc".b, out
      assert_equal "warn", err
    end
  end

  test "a failed command is a failure, a broken sandbox is an error" do
    with_bridge(->(request) { request["args"] == [ "bad" ] ? { error: "VM gone" } : { exitCode: 128, stdout: "", stderr: "fatal" } }) do |session|
      assert_equal [ "", "fatal", false ], session.capture({}, %w[git x], "/tmp", timeout: 5)
      assert_raises(VercelSandbox::Error) { session.capture({}, %w[git bad], "/tmp", timeout: 5) }
    end
  end

  test "gives up on a bridge that stops answering" do
    reader, writer = IO.pipe
    session = VercelSandbox::Session.new(File.open(File::NULL, "w"), reader)
    error = assert_raises(VercelSandbox::Error) { session.receive(0.2) }
    assert_match "too long", error.message
  ensure
    writer&.close
    reader&.close
  end

  test "isn't used without all three credentials" do
    with_env("VERCEL_SANDBOX_TOKEN" => "t", "VERCEL_SANDBOX_TEAM_ID" => "team", "VERCEL_SANDBOX_PROJECT_ID" => nil) do
      refute VercelSandbox.configured?
    end
  end

  private

  # A Session wired to a fake bridge that answers each request line with reply.(request).
  def with_bridge(reply)
    requests, request_writer = IO.pipe
    replies, reply_writer = IO.pipe
    bridge = Thread.new do
      requests.each_line { |line| reply_writer.puts(reply.(JSON.parse(line)).to_json) }
    end
    yield VercelSandbox::Session.new(request_writer, replies)
  ensure
    request_writer&.close
    bridge&.join(1)
    [ requests, replies, reply_writer ].each { it&.close }
  end
end
