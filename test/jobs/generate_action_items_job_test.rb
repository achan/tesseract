require "test_helper"

class GenerateActionItemsJobTest < ActiveSupport::TestCase
  test "creates action items using Codex" do
    channel = slack_channels(:general)
    event = channel.slack_events.create!(
      event_id: "Ev_CODEX_ACTION",
      event_type: "message",
      user_id: "U_USER1",
      ts: "1700000020.000001",
      payload: { "text" => "Please review the pull request", "type" => "message" }
    )
    response = {
      "action_items" => [
        {
          "description" => "Review the pull request",
          "assignee" => "U_USER1",
          "source_ts" => event.ts,
          "priority" => 2
        }
      ]
    }.to_json

    assert_difference "ActionItem.count", 1 do
      CodexClient.stub(:call, response) do
        GenerateActionItemsJob.perform_now(slack_event_id: event.id)
      end
    end

    action_item = ActionItem.find_by!(source: channel, source_ts: event.ts)
    assert_equal "Review the pull request", action_item.description
    assert_equal 2, action_item.priority
  end

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
