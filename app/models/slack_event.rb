class SlackEvent < ApplicationRecord
  belongs_to :slack_channel

  has_many :feed_items, as: :source, dependent: :destroy

  validates :event_id, presence: true, uniqueness: true

  scope :in_window, ->(start_time, end_time) { where(created_at: start_time..end_time) }
  scope :messages, -> { where(event_type: "message").where("json_extract(payload, '$.subtype') IS NULL OR json_extract(payload, '$.subtype') != ?", "message_changed") }

  after_create_commit :broadcast_event, :enqueue_action_items_job, :enqueue_create_feed_items

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

  def enqueue_action_items_job
    return unless slack_channel.actionable?

    GenerateActionItemsJob.set(wait: 90.seconds).perform_later(slack_event_id: id)
  end

  def enqueue_create_feed_items
    return unless event_type == "message"
    return if payload&.dig("subtype") == "message_changed"

    CreateFeedItemsJob.perform_later(slack_event_id: id)
  end
end
