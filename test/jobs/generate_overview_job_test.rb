require "test_helper"

class GenerateOverviewJobTest < ActiveSupport::TestCase
  test "creates an overview using Codex" do
    profile = profiles(:one)
    workspaces(:one).update!(user_token: nil)
    response = {
      "summary" => "Engineering work progressed.",
      "details" => "**Engineering**\n\n- The team discussed project updates."
    }.to_json

    assert_difference "Overview.count", 1 do
      CodexClient.stub(:call, response) do
        GenerateOverviewJob.perform_now(profile_id: profile.id)
      end
    end

    overview = Overview.find_by!(model_used: "codex-cli")
    assert_equal profile, overview.profile
    assert_equal "Engineering work progressed.", overview.summary
  end
end
