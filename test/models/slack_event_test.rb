require "test_helper"

class SlackEventTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  test "validates event_id presence" do
    event = SlackEvent.new(slack_channel: slack_channels(:general))
    assert_not event.valid?
    assert_includes event.errors[:event_id], "can't be blank"
  end

  test "validates event_id uniqueness" do
    event = SlackEvent.new(
      slack_channel: slack_channels(:general),
      event_id: slack_events(:message_one).event_id
    )
    assert_not event.valid?
    assert_includes event.errors[:event_id], "has already been taken"
  end

  test "in_window scope filters by created_at range" do
    events = SlackEvent.in_window(2.days.ago, Time.current)
    assert events.all? { |e| e.created_at >= 2.days.ago }
  end

  test "does not enqueue action items job when slack event is created" do
    channel = slack_channels(:general)

    assert_no_enqueued_jobs(only: GenerateActionItemsJob) do
      channel.slack_events.create!(
        event_id: "Ev_NO_ACTION_ITEMS_TEST",
        event_type: "message",
        ts: "1700000099.000001",
        payload: { "text" => "test", "type" => "message" }
      )
    end
  end
end
