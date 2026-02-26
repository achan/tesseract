class FeedSource < ApplicationRecord
  belongs_to :feed
  belongs_to :source, polymorphic: true
end
