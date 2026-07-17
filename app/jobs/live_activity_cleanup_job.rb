class LiveActivityCleanupJob < ApplicationJob
  def perform(live_activity_id, stale_before: nil)
    activity = LiveActivity.find_by(id: live_activity_id)
    return unless activity

    if activity.ends_at && activity.ends_at <= Time.current
      remove_activity(activity)
      return
    end

    return unless stale_before
    return unless activity.activity_type == "codex"
    return unless activity.status == "active"
    return unless activity.updated_at <= stale_before

    remove_activity(activity)
  end

  private

  def remove_activity(activity)
    activity.broadcast_remove_to("dashboard_live_activities", target: "live_activity_#{activity.id}")
    activity.destroy
  end
end
