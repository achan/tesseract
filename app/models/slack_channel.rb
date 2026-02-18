class SlackChannel < ApplicationRecord
  belongs_to :workspace

  has_many :slack_events, dependent: :destroy
  has_many :summaries, as: :source, dependent: :destroy
  has_many :action_items, as: :source, dependent: :destroy

  validates :channel_id, presence: true, uniqueness: { scope: :workspace_id }

  scope :active, -> { where(active: true) }
end
