class SlackChannel < ApplicationRecord
  belongs_to :workspace

  has_many :slack_events, dependent: :destroy
  has_many :summaries, as: :source, dependent: :destroy
  has_many :action_items, as: :source, dependent: :destroy

  validates :channel_id, presence: true, uniqueness: { scope: :workspace_id }

  before_save :populate_channel_name, if: -> { channel_name.blank? && workspace&.user_token.present? }

  scope :active, -> { where(active: true) }
  scope :channels, -> { where.not("channel_id LIKE 'D%' OR channel_id LIKE 'G%'") }

  private

  def populate_channel_name
    client = workspace.slack_client
    info = client.conversations_info(channel: channel_id)
    channel = info.channel

    self.channel_name = channel.name || channel.purpose&.value.presence || resolve_im_name(client, channel)
  rescue Slack::Web::Api::Errors::SlackError
    # Leave channel_name blank if the API call fails
  end

  def resolve_im_name(client, channel)
    return unless channel.is_im

    name = begin
      info = client.users_info(user: channel.user)
      info.user.real_name.presence || info.user.name
    rescue Slack::Web::Api::Errors::SlackError
      channel.user
    end

    "DM: #{name}"
  end
end
