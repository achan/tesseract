class RemoteControlSession < ApplicationRecord
  LOG_FILE = Rails.root.join("tmp/claude_remote_control.log")
  URL_PATTERN = /https:\/\/claude\.ai\/code\/\S+/

  scope :active, -> { where(status: %w[starting running]) }

  after_create_commit :enqueue_start_job
  after_update_commit :broadcast_status

  def self.current
    active.last
  end

  def stop!
    return unless status.in?(%w[starting running])

    update!(status: "stopping")
    RemoteControlStopJob.perform_later(id)
  end

  def process_alive?
    return false unless pid

    Process.kill(0, pid)
    true
  rescue Errno::ESRCH, Errno::EPERM
    false
  end

  private

  def enqueue_start_job
    RemoteControlStartJob.perform_later(id)
  end

  def broadcast_status
    Turbo::StreamsChannel.broadcast_replace_to(
      "settings_remote_control",
      target: "remote_control_status",
      partial: "settings/remote_control_status",
      locals: { session: self }
    )
  end
end
