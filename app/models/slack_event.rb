class SlackEvent < ApplicationRecord
  belongs_to :slack_channel

  validates :event_id, presence: true, uniqueness: true

  scope :in_window, ->(start_time, end_time) { where(created_at: start_time..end_time) }
  scope :messages, -> { where(event_type: "message") }

  after_create_commit :broadcast_event, :broadcast_to_dashboard

  private

  def broadcast_event
    channel = slack_channel
    broadcast_prepend_to(
      "workspace_#{channel.workspace_id}_channel_#{channel.channel_id}_events",
      target: "events",
      partial: "slack_events/event",
      locals: { event: self }
    )
  end

  def broadcast_to_dashboard
    return unless event_type == "message"
    return if slack_channel.hidden?

    broadcast_prepend_to(
      "dashboard_events",
      target: "dashboard_events",
      partial: "dashboard/event",
      locals: { event: self }
    )
  end
end
