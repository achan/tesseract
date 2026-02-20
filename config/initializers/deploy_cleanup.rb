Rails.application.config.after_initialize do
  commit_sha = Rails.cache.read("deploy:pending")
  next unless commit_sha

  Rails.cache.delete("deploy:pending")

  activity = LiveActivity.find_by(activity_type: "deploy", activity_id: commit_sha, status: "active")
  next unless activity

  activity.update!(status: "ending", ends_at: 10.seconds.from_now)
  LiveActivityCleanupJob.set(wait: 10.seconds).perform_later(activity.id)
end
