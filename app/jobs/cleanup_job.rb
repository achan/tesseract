class CleanupJob < ApplicationJob
  queue_as :default

  RETENTION_PERIOD = 3.months

  def perform
    cutoff = RETENTION_PERIOD.ago

    events_deleted = SlackEvent.where("created_at < ?", cutoff).delete_all

    Rails.logger.info("[CleanupJob] Deleted: #{events_deleted} events")
  end
end
