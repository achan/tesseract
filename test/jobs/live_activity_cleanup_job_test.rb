require "test_helper"

class LiveActivityCleanupJobTest < ActiveSupport::TestCase
  test "removes ended live activities" do
    activity = LiveActivity.create!(
      activity_type: "deploy",
      activity_id: "deploy-1",
      title: "Deploying",
      status: "ending",
      ends_at: 1.second.ago
    )

    LiveActivityCleanupJob.perform_now(activity.id)

    assert_not LiveActivity.exists?(activity.id)
  end

  test "removes stale active codex activities" do
    activity = LiveActivity.create!(
      activity_type: "codex",
      activity_id: "session-1:turn-1",
      title: "tesseract-web@tars",
      status: "active"
    )
    stale_before = activity.updated_at

    LiveActivityCleanupJob.perform_now(activity.id, stale_before: stale_before)

    assert_not LiveActivity.exists?(activity.id)
  end

  test "keeps codex activities with newer updates" do
    activity = LiveActivity.create!(
      activity_type: "codex",
      activity_id: "session-2:turn-1",
      title: "tesseract-web@tars",
      status: "active"
    )
    stale_before = activity.updated_at
    activity.update!(metadata: { "status" => "Still working" })

    LiveActivityCleanupJob.perform_now(activity.id, stale_before: stale_before)

    assert LiveActivity.exists?(activity.id)
  end

  test "does not remove stale non-codex active activities" do
    activity = LiveActivity.create!(
      activity_type: "cleanup",
      activity_id: "cleanup-1",
      title: "Cleaning up",
      status: "active"
    )

    LiveActivityCleanupJob.perform_now(activity.id, stale_before: activity.updated_at)

    assert LiveActivity.exists?(activity.id)
  end
end
