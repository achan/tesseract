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

    assert_no_difference "ActionItem.count" do
      GenerateActionItemsJob.perform_now(slack_event_id: old_event.id)
    end
  end

  test "noops when event does not exist" do
    assert_no_difference "ActionItem.count" do
      GenerateActionItemsJob.perform_now(slack_event_id: -1)
    end
  end
end
