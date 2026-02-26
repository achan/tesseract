class BackfillFeedItemsJob < ApplicationJob
  queue_as :default

  def perform(feed_id:)
    feed = Feed.find_by(id: feed_id)
    return unless feed

    channel_ids = feed.feed_sources.where(source_type: "SlackChannel").pluck(:source_id)
    return if channel_ids.empty?

    now = Time.current
    SlackEvent.messages.where(slack_channel_id: channel_ids).where("created_at > ?", 24.hours.ago).find_each do |event|
      FeedItem.insert(
        { feed_id: feed.id, source_type: "SlackEvent", source_id: event.id,
          occurred_at: event.created_at, created_at: now, updated_at: now },
        unique_by: :index_feed_items_uniqueness
      )
    end
  end
end
