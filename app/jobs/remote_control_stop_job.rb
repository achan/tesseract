class RemoteControlStopJob < ApplicationJob
  queue_as :default

  def perform(session_id)
    session = RemoteControlSession.find(session_id)

    if session.pid && session.process_alive?
      Process.kill("TERM", session.pid)
      # Give it a moment to shut down gracefully (SessionEnd hook will fire)
      sleep 2
      Process.kill("KILL", session.pid) if session.process_alive?
    end

    session.update!(status: "stopped") unless session.status == "stopped"
  rescue Errno::ESRCH, Errno::EPERM
    session.update!(status: "stopped") unless session.status == "stopped"
  end
end
