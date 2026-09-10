require "open3"
require "tmpdir"

class CodexClient
  class Error < StandardError; end

  class << self
    def call(prompt, output_schema: nil)
      stdout, stderr, status = Open3.capture3(
        { "CODEX_API_KEY" => nil, "OPENAI_API_KEY" => nil },
        *command(output_schema: output_schema),
        stdin_data: prompt,
        chdir: Dir.tmpdir
      )

      unless status.success?
        diagnostic = stderr.presence || stdout
        raise Error, "codex CLI failed (exit #{status.exitstatus}): #{diagnostic.strip}"
      end

      stdout.strip.presence || raise(Error, "codex CLI returned an empty response")
    end

    private

    def command(output_schema:)
      command = [
        "codex", "--ask-for-approval", "never", "exec",
        "--ephemeral",
        "--ignore-user-config",
        "--ignore-rules",
        "--skip-git-repo-check",
        "--sandbox", "read-only",
        "--color", "never",
        "--disable", "shell_tool",
        "--disable", "unified_exec",
        "--config", 'web_search="disabled"'
      ]

      command.concat([ "--model", ENV["CODEX_MODEL"] ]) if ENV["CODEX_MODEL"].present?
      command.concat([ "--output-schema", output_schema.to_s ]) if output_schema
      command << "-"
    end
  end
end
