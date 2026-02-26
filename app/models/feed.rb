class Feed < ApplicationRecord
  has_many :feed_sources, dependent: :destroy
  has_many :feed_items, dependent: :destroy

  validates :name, presence: true

  scope :ordered, -> { order(position: :asc) }

  def stream_name
    "feed_#{id}"
  end

  def auto_include_workspace_ids
    feed_sources.where(source_type: "Workspace").pluck(:source_id)
  end
end
