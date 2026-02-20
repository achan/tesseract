class DeployTimeoutJob < ApplicationJob
  def perform(commit_sha)
    activity = LiveActivity.find_by(activity_type: "deploy", activity_id: commit_sha, status: "active")
    return unless activity

    activity.update!(status: "ending", ends_at: 10.seconds.from_now)
    LiveActivityCleanupJob.set(wait: 10.seconds).perform_later(activity.id)
    Rails.cache.delete("deploy:pending")
  end
end
