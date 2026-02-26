class FeedItem < ApplicationRecord
  belongs_to :feed
  belongs_to :source, polymorphic: true

  scope :ordered, -> { order(occurred_at: :desc) }

  after_create_commit :broadcast_to_feed

  private

  def broadcast_to_feed
    broadcast_prepend_to(
      feed.stream_name,
      target: "feed_#{feed.id}_items",
      partial: "dashboard/event",
      locals: { event: source }
    )
  end
end
