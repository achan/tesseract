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

  test "enqueues action items job when channel is actionable" do
    channel = slack_channels(:general)
    assert channel.actionable?

    assert_enqueued_with(job: GenerateActionItemsJob) do
      channel.slack_events.create!(
        event_id: "Ev_ACTIONABLE_TEST",
        event_type: "message",
        ts: "1700000099.000001",
        payload: { "text" => "test", "type" => "message" }
      )
    end
  end

  test "does not enqueue action items job when channel is not actionable" do
    channel = slack_channels(:general)
    channel.update!(actionable: false)

    assert_no_enqueued_jobs(only: GenerateActionItemsJob) do
      channel.slack_events.create!(
        event_id: "Ev_NOT_ACTIONABLE_TEST",
        event_type: "message",
        ts: "1700000100.000001",
        payload: { "text" => "test", "type" => "message" }
      )
    end
  end
end
