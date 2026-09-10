require "test_helper"

class SummarizeJobTest < ActiveSupport::TestCase
  test "creates a summary using Codex" do
    workspace = workspaces(:one)
    workspace.update!(user_token: nil)

    assert_difference "Summary.count", 1 do
      CodexClient.stub(:call, "The team discussed project updates.") do
        SummarizeJob.perform_now(
          workspace_id: workspace.id,
          channel_id: "C_GENERAL",
          period_start: 1.day.ago,
          period_end: 1.day.from_now
        )
      end
    end

    summary = Summary.find_by!(model_used: "codex-cli")
    assert_equal "The team discussed project updates.", summary.summary_text
  end

  test "groups events by thread" do
    channel = slack_channels(:general)
    job = SummarizeJob.new

    SlackEvent.create!(
      slack_channel: channel,
      event_id: "Ev_THREAD_001",
      event_type: "message",
      user_id: "U_USER2",
      ts: "1700000002.000001",
      thread_ts: "1700000001.000001",
      payload: { "text" => "Reply in thread", "type" => "message" }
    )

    events = channel.slack_events.in_window(2.days.ago, Time.current).order(:created_at)
    grouped = job.send(:group_by_thread, events)

    assert grouped[:top_level].any? { |e| e.ts == "1700000001.000001" }
    assert grouped[:threads]["1700000001.000001"]&.any? { |e| e.ts == "1700000002.000001" }
  end

  test "skips when no events in window" do
    workspace = workspaces(:one)

    assert_no_difference "Summary.count" do
      SummarizeJob.perform_now(
        workspace_id: workspace.id,
        channel_id: "C_GENERAL",
        period_start: 10.years.ago,
        period_end: 9.years.ago
      )
    end
  end
end
