class RemoteControlStartJob < ApplicationJob
  queue_as :default

  def perform(session_id)
    session = RemoteControlSession.find(session_id)
    return unless session.status == "starting"

    log_file = RemoteControlSession::LOG_FILE
    FileUtils.touch(log_file)

    env = {
      "TESSERACT_RC_SESSION_ID" => session.id.to_s,
      "TESSERACT_URL" => ENV.fetch("TESSERACT_URL", "http://localhost:3000")
    }

    pid = Process.spawn(
      env,
      "claude", "code", "--remote",
      chdir: Rails.root.to_s,
      out: log_file.to_s,
      err: log_file.to_s
    )
    Process.detach(pid)

    session.update!(pid: pid)
  rescue => e
    session&.update(status: "error", error_message: e.message)
  end
end
