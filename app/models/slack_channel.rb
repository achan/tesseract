class SlackChannel < ApplicationRecord
  belongs_to :workspace

  has_many :slack_events, dependent: :destroy
  has_many :summaries, as: :source, dependent: :destroy
  has_many :action_items, as: :source, dependent: :destroy

  validates :channel_id, presence: true, uniqueness: { scope: :workspace_id }

  before_save :populate_channel_name, if: -> { channel_name_unresolved? && workspace&.user_token.present? }

  scope :active, -> { where(active: true) }
  scope :channels, -> { where.not("channel_id LIKE 'D%' OR channel_id LIKE 'G%'") }

  def display_name
    channel_name.presence || channel_id
  end

  def mpim?
    channel_id.start_with?("G")
  end

  def dm?
    channel_id.start_with?("D")
  end

  def dm_partner_profile
    return unless dm? && workspace&.user_token.present?

    # DM channel_name is stored as "DM: Name" by populate_channel_name
    # Extract the user_id from the conversation info
    Rails.cache.fetch("slack_dm_partner/#{id}", expires_in: 1.hour) do
      info = workspace.slack_client.conversations_info(channel: channel_id)
      workspace.resolve_user_profile(info.channel.user)
    end
  rescue Slack::Web::Api::Errors::SlackError, Faraday::Error
    nil
  end

  def member_profiles
    return [] unless mpim? && workspace&.user_token.present?

    Rails.cache.fetch("slack_channel_members/#{id}", expires_in: 1.hour) do
      members = workspace.slack_client.conversations_members(channel: channel_id, limit: 10).members
      members.map { |uid| workspace.resolve_user_profile(uid) }
    end
  rescue Slack::Web::Api::Errors::SlackError, Faraday::Error
    []
  end

  private

  def channel_name_unresolved?
    channel_name.blank? || channel_name == channel_id
  end

  def populate_channel_name
    client = workspace.slack_client
    info = client.conversations_info(channel: channel_id)
    channel = info.channel

    self.channel_name = channel.name.presence ||
      resolve_im_name(client, channel) ||
      resolve_mpim_name(client, channel) ||
      channel.purpose&.value.presence
  rescue Slack::Web::Api::Errors::SlackError, Faraday::Error
    # Leave channel_name as-is if the API call fails
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

  def resolve_mpim_name(client, channel)
    return unless channel.is_mpim

    members = client.conversations_members(channel: channel.id, limit: 10).members
    names = members.filter_map do |uid|
      info = client.users_info(user: uid)
      info.user.real_name.presence || info.user.name
    rescue Slack::Web::Api::Errors::SlackError
      uid
    end

    "Group: #{names.join(", ")}"
  end
end
