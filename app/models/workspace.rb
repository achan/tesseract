class Workspace < ApplicationRecord
  encrypts :user_token

  has_many :slack_channels, dependent: :destroy

  validates :team_id, presence: true, uniqueness: true

  def active_channel_ids
    slack_channels.active.pluck(:channel_id)
  end
end
