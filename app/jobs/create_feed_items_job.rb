class CreateFeedItemsJob < ApplicationJob
  queue_as :default

  def perform(slack_event_id:)
    event = SlackEvent.find_by(id: slack_event_id)
    return unless event

    feeds = Feed.joins(:feed_sources).where(
      feed_sources: { source_type: "SlackChannel", source_id: event.slack_channel_id }
    )

    feeds.find_each do |feed|
      feed.feed_items.create!(source: event, occurred_at: event.created_at)
    end
  end
end
