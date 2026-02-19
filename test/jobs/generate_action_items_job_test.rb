require "test_helper"

class GenerateActionItemsJobTest < ActiveSupport::TestCase
  test "noops when event is stale (newer event exists)" do
    channel = slack_channels(:general)
    old_event = channel.slack_events.create!(
      event_id: "Ev_ACTION_OLD",
      event_type: "message",
      user_id: "U_USER1",
      ts: "1700000010.000001",
      payload: { "text" => "older message", "type" => "message" }
    )
    channel.slack_events.create!(
      event_id: "Ev_ACTION_NEW",
      event_type: "message",
      user_id: "U_USER1",
      ts: "1700000011.000001",
      payload: { "text" => "newer message", "type" => "message" }
    )

    assert_no_difference "Summary.count" do
      GenerateActionItemsJob.perform_now(slack_event_id: old_event.id)
    end
  end

  test "delegates to SummarizeJob when event is the latest" do
    channel = slack_channels(:general)
    latest_event = channel.slack_events.order(created_at: :desc).first

    called_with = nil
    original = SummarizeJob.instance_method(:perform)
    SummarizeJob.define_method(:perform) { |**kwargs| called_with = kwargs }

    GenerateActionItemsJob.perform_now(slack_event_id: latest_event.id)

    assert_equal({ workspace_id: channel.workspace_id, channel_id: channel.channel_id }, called_with)
  ensure
    SummarizeJob.define_method(:perform, original)
  end

  test "noops when event does not exist" do
    assert_no_difference "Summary.count" do
      GenerateActionItemsJob.perform_now(slack_event_id: -1)
    end
  end
end
