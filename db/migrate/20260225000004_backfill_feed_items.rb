class BackfillFeedItems < ActiveRecord::Migration[8.0]
  def up
    Feed.find_each do |feed|
      channel_ids = FeedSource.where(feed_id: feed.id, source_type: "SlackChannel").pluck(:source_id)
      next if channel_ids.empty?

      SlackEvent.where(event_type: "message")
        .where("json_extract(payload, '$.subtype') IS NULL OR json_extract(payload, '$.subtype') != ?", "message_changed")
        .where(slack_channel_id: channel_ids)
        .find_each do |event|
          FeedItem.create_or_find_by!(feed_id: feed.id, source_type: "SlackEvent", source_id: event.id) do |fi|
            fi.occurred_at = event.created_at
          end
        end
    end
  end

  def down
    FeedItem.delete_all
  end
end
