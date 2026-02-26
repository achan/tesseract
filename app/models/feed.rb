class Feed < ApplicationRecord
  has_many :feed_sources, dependent: :destroy
  has_many :feed_items, dependent: :destroy

  validates :name, presence: true

  scope :ordered, -> { order(position: :asc) }

  def stream_name
    "feed_#{id}"
  end

  def auto_include_workspace_ids
    feed_sources.where(source_type: "Workspace").select(&:auto_include_new_channels?).map(&:source_id)
  end

  def include_dms_workspace_ids
    feed_sources.where(source_type: "Workspace").select(&:include_dms?).map(&:source_id)
  end
end
