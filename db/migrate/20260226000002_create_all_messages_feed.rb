class CreateAllMessagesFeed < ActiveRecord::Migration[8.0]
  def up
    # Shift existing feeds to make room at position 0
    Feed.order(position: :desc).each do |f|
      f.update_column(:position, f.position + 1)
    end

    feed = Feed.create!(name: "All Messages", position: 0)

    # Add every visible, current, non-DM channel as a source
    channels = SlackChannel.visible.channels.current
    channels.find_each do |channel|
      FeedSource.create!(feed: feed, source: channel)
    end

    # Add workspace sources with auto_include_new_channels so future
    # channels flow in automatically
    workspace_ids = channels.distinct.pluck(:workspace_id)
    workspace_ids.each do |wid|
      FeedSource.create!(
        feed: feed,
        source_type: "Workspace",
        source_id: wid,
        options: { "auto_include_new_channels" => true, "include_dms" => false }
      )
    end

    # Backfill existing messages from those channels
    channel_ids = channels.pluck(:id)
    return if channel_ids.empty?

    now = Time.current
    SlackEvent.messages.where(slack_channel_id: channel_ids).find_each do |event|
      FeedItem.insert(
        { feed_id: feed.id, source_type: "SlackEvent", source_id: event.id,
          occurred_at: event.created_at, created_at: now, updated_at: now },
        unique_by: :index_feed_items_uniqueness
      )
    end
  end

  def down
    feed = Feed.find_by(name: "All Messages", position: 0)
    return unless feed

    feed.destroy!

    # Compact positions back down
    Feed.order(position: :asc).each_with_index do |f, i|
      f.update_column(:position, i)
    end
  end
end
