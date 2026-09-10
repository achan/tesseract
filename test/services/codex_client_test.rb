require "test_helper"

class CodexClientTest < ActiveSupport::TestCase
  setup do
    @original_codex_model = ENV.delete("CODEX_MODEL")
  end

  teardown do
    ENV["CODEX_MODEL"] = @original_codex_model
  end

  test "runs Codex with an isolated non-interactive configuration" do
    captured = {}
    capture3 = lambda do |*arguments, **options|
      captured[:arguments] = arguments
      captured[:options] = options
      [ " final response \n", "progress", process_status(success: true, exitstatus: 0) ]
    end

    result = Open3.stub(:capture3, capture3) do
      CodexClient.call("Summarize this")
    end

    environment, *command = captured[:arguments]
    assert_equal({ "CODEX_API_KEY" => nil, "OPENAI_API_KEY" => nil }, environment)
    assert_equal [
      "codex", "--ask-for-approval", "never", "exec",
      "--ephemeral",
      "--ignore-user-config",
      "--ignore-rules",
      "--skip-git-repo-check",
      "--sandbox", "read-only",
      "--color", "never",
      "--disable", "shell_tool",
      "--disable", "unified_exec",
      "--config", 'web_search="disabled"',
      "-"
    ], command
    assert_equal "Summarize this", captured[:options][:stdin_data]
    assert_equal Dir.tmpdir, captured[:options][:chdir]
    assert_equal "final response", result
  end

  test "passes optional model and output schema" do
    ENV["CODEX_MODEL"] = "test-model"
    captured_arguments = nil
    capture3 = lambda do |*arguments, **|
      captured_arguments = arguments
      [ "{}", "", process_status(success: true, exitstatus: 0) ]
    end

    Open3.stub(:capture3, capture3) do
      CodexClient.call("Extract data", output_schema: Pathname("/tmp/schema.json"))
    end

    command = captured_arguments.drop(1)
    assert_equal "test-model", command[command.index("--model") + 1]
    assert_equal "/tmp/schema.json", command[command.index("--output-schema") + 1]
  end

  test "raises with stderr when Codex exits unsuccessfully" do
    capture3 = lambda do |*, **|
      [ "", "authentication failed\n", process_status(success: false, exitstatus: 7) ]
    end

    error = Open3.stub(:capture3, capture3) do
      assert_raises(CodexClient::Error) { CodexClient.call("sensitive prompt") }
    end

    assert_equal "codex CLI failed (exit 7): authentication failed", error.message
    assert_not_includes error.message, "sensitive prompt"
  end

  test "raises when Codex returns an empty response" do
    capture3 = lambda do |*, **|
      [ " \n", "", process_status(success: true, exitstatus: 0) ]
    end

    error = Open3.stub(:capture3, capture3) do
      assert_raises(CodexClient::Error) { CodexClient.call("prompt") }
    end

    assert_equal "codex CLI returned an empty response", error.message
  end

  private

  def process_status(success:, exitstatus:)
    Object.new.tap do |status|
      status.define_singleton_method(:success?) { success }
      status.define_singleton_method(:exitstatus) { exitstatus }
    end
  end
end
