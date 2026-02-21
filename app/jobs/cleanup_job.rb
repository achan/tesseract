class CleanupJob < ApplicationJob
  queue_as :default

  RETENTION_PERIOD = 3.months

  WONT_FIX_ARCHIVE_AFTER = 36.hours

  def perform
    start_live_activity(
      activity_type: "cleanup",
      activity_id: Date.current.to_s,
      title: "Cleaning up old data"
    )

    cutoff = RETENTION_PERIOD.ago
    events_deleted = SlackEvent.where("created_at < ?", cutoff).delete_all

    wont_fix_archived = ActionItem.active
      .where(status: "wont_fix")
      .where("updated_at < ?", WONT_FIX_ARCHIVE_AFTER.ago)
      .update_all(archived_at: Time.current)

    Rails.logger.info("[CleanupJob] Deleted: #{events_deleted} events, auto-archived: #{wont_fix_archived} wont_fix items")

    stop_live_activity(metadata: { "events_deleted" => events_deleted, "wont_fix_archived" => wont_fix_archived })
  end
end
