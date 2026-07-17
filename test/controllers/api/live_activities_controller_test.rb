require "test_helper"

class Api::LiveActivitiesControllerTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  setup do
    clear_enqueued_jobs
  end

  test "schedules stale cleanup for codex starts" do
    post start_api_live_activities_path, params: {
      activity_type: "codex",
      activity_id: "session-1:turn-1",
      title: "tesseract-web@tars",
      metadata: { worktree: "main", status: "Working" }
    }

    assert_response :ok
    assert_equal 1, enqueued_jobs.count { |job| job[:job] == LiveActivityCleanupJob }
  end

  test "does not schedule stale cleanup for non-codex starts" do
    post start_api_live_activities_path, params: {
      activity_type: "deploy",
      activity_id: "deploy-1",
      title: "Deploying"
    }

    assert_response :ok
    assert_equal 0, enqueued_jobs.count { |job| job[:job] == LiveActivityCleanupJob }
  end
end
