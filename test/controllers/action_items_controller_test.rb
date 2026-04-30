require "test_helper"

class ActionItemsControllerTest < ActionDispatch::IntegrationTest
  test "new can lock source to a slack event" do
    event = slack_events(:message_one)

    get new_action_item_path(
      format: :turbo_stream,
      source_type: "SlackEvent",
      source_id: event.id,
      source_ts: event.ts
    )

    assert_response :success
    assert_includes response.body, "New Action Item"
    assert_includes response.body, "Message in #general"
    assert_includes response.body, %(value="SlackEvent" name="action_item[source_type]")
    assert_includes response.body, %(value="#{event.id}" name="action_item[source_id]")
    assert_includes response.body, %(value="#{event.ts}" name="action_item[source_ts]")
  end

  test "create supports slack event source" do
    event = slack_events(:message_one)

    assert_difference "ActionItem.count", 1 do
      post action_items_path(format: :turbo_stream), params: {
        action_item: {
          description: "Follow up from the deck card",
          priority: 3,
          status: "untriaged",
          source_type: "SlackEvent",
          source_id: event.id,
          source_ts: event.ts
        }
      }
    end

    assert_response :success
    item = ActionItem.order(:created_at).last
    assert_equal event, item.source
    assert_equal event.ts, item.source_ts
  end

  test "index renders source card for slack event sourced action items" do
    event = slack_events(:message_one)
    ActionItem.create!(
      description: "Follow up from the deck card",
      priority: 3,
      status: "untriaged",
      source: event,
      source_ts: event.ts
    )

    get action_items_path

    assert_response :success
    assert_includes response.body, "Follow up from the deck card"
    assert_includes response.body, "Hello world"
    assert_includes response.body, "action_item_"
    assert_includes response.body, "_source_#{event.id}"
  end
end
