class CleanupJob < ApplicationJob
  queue_as :default

  RETENTION_PERIOD = 3.months

  def perform
    start_live_activity(
      activity_type: "cleanup",
      activity_id: Date.current.to_s,
      title: "Cleaning up old data"
    )

    cutoff = RETENTION_PERIOD.ago

    events_deleted = SlackEvent.where("created_at < ?", cutoff).delete_all

    Rails.logger.info("[CleanupJob] Deleted: #{events_deleted} events")

    stop_live_activity(metadata: { "events_deleted" => events_deleted })
  end
end
