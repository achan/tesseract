class CleanupJob < ApplicationJob
  queue_as :default

  RETENTION_PERIOD = 3.days

  def perform
    cutoff = RETENTION_PERIOD.ago

    # Delete action items first (FK to summaries)
    action_items_deleted = ActionItem
      .where("created_at < ?", cutoff)
      .where.not(status: "open")
      .delete_all

    # Delete summaries that have no remaining action items
    old_summary_ids = Summary.where("created_at < ?", cutoff).pluck(:id)
    summaries_with_items = ActionItem.where(summary_id: old_summary_ids).distinct.pluck(:summary_id)
    deletable_summary_ids = old_summary_ids - summaries_with_items
    summaries_deleted = Summary.where(id: deletable_summary_ids).delete_all

    events_deleted = SlackEvent.where("created_at < ?", cutoff).delete_all

    Rails.logger.info(
      "[CleanupJob] Deleted: #{events_deleted} events, " \
      "#{summaries_deleted} summaries, " \
      "#{action_items_deleted} action items"
    )
  end
end
