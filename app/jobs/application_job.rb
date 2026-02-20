class ApplicationJob < ActiveJob::Base
  # Automatically retry jobs that encountered a deadlock
  # retry_on ActiveRecord::Deadlocked

  # Most jobs are safe to ignore if the underlying records are no longer available
  # discard_on ActiveJob::DeserializationError

  private

  def start_live_activity(activity_type:, activity_id:, title:, subtitle: nil, metadata: {})
    @live_activity = LiveActivity.find_or_initialize_by(
      activity_type: activity_type,
      activity_id: activity_id
    )
    @live_activity.assign_attributes(
      title: title,
      subtitle: subtitle,
      metadata: metadata,
      status: "active",
      ends_at: nil
    )
    @live_activity.save!
  rescue => e
    Rails.logger.warn("[LiveActivity] start failed: #{e.message}")
  end

  def update_live_activity(subtitle: nil, metadata: {})
    return unless @live_activity

    @live_activity.subtitle = subtitle if subtitle
    @live_activity.metadata = @live_activity.metadata.merge(metadata) if metadata.present?
    @live_activity.save!
  rescue => e
    Rails.logger.warn("[LiveActivity] update failed: #{e.message}")
  end

  def stop_live_activity(metadata: {})
    return unless @live_activity

    @live_activity.metadata = @live_activity.metadata.merge(metadata) if metadata.present?
    @live_activity.update!(status: "ending", ends_at: 10.seconds.from_now)
    LiveActivityCleanupJob.set(wait: 10.seconds).perform_later(@live_activity.id)
  rescue => e
    Rails.logger.warn("[LiveActivity] stop failed: #{e.message}")
  end
end
