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
    referenced_event_ids = ActionItem.where(source_type: "SlackEvent").select(:source_id)
    events_deleted = SlackEvent.where("created_at < ?", cutoff).where.not(id: referenced_event_ids).delete_all
    feed_items_deleted = FeedItem.where("occurred_at < ?", cutoff).delete_all

    wont_fix_archived = ActionItem.active
      .where(status: "wont_fix")
      .where("updated_at < ?", WONT_FIX_ARCHIVE_AFTER.ago)
      .update_all(archived_at: Time.current)

    Rails.logger.info("[CleanupJob] Deleted: #{events_deleted} events, #{feed_items_deleted} feed items, auto-archived: #{wont_fix_archived} wont_fix items")

    stop_live_activity(metadata: { "events_deleted" => events_deleted, "feed_items_deleted" => feed_items_deleted, "wont_fix_archived" => wont_fix_archived })
  end
end
