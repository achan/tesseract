class SlackChannel < ApplicationRecord
  belongs_to :workspace
  belongs_to :predecessor, class_name: "SlackChannel", optional: true
  has_one :successor, class_name: "SlackChannel", foreign_key: :predecessor_id, dependent: :nullify

  has_many :slack_events, dependent: :destroy
  has_many :summaries, as: :source, dependent: :destroy
  has_many :action_items, as: :source, dependent: :destroy

  validates :channel_id, presence: true, uniqueness: { scope: :workspace_id }

  before_save :populate_channel_name, if: -> { channel_name_unresolved? && workspace&.user_token.present? }
  after_create :link_predecessor

  scope :visible, -> { where(hidden: false) }
  scope :channels, -> { where.not("channel_id LIKE 'D%' OR channel_id LIKE 'G%'") }
  scope :current, -> { left_joins(:successor).where(successor: { id: nil }) }

  def display_name
    channel_name.presence || channel_id
  end

  def mpim?
    channel_id.start_with?("G") || channel_name&.start_with?("mpdm-")
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

  # --- Channel chain traversal ---

  def predecessor_chain
    chain = []
    current = predecessor
    while current
      chain << current
      current = current.predecessor
    end
    chain
  end

  def channel_chain
    [self] + predecessor_chain
  end

  def channel_chain_ids
    channel_chain.map(&:id)
  end

  # --- Aggregated queries across merged channel chain ---

  def all_slack_events
    SlackEvent.where(slack_channel_id: channel_chain_ids)
  end

  def all_summaries
    Summary.where(source_type: "SlackChannel", source_id: channel_chain_ids)
  end

  def all_action_items
    ActionItem.where(source_type: "SlackChannel", source_id: channel_chain_ids)
  end

  private

  def link_predecessor
    return if channel_name.blank? || channel_name == channel_id || dm? || mpim?

    predecessor_channel = SlackChannel
      .where(workspace_id: workspace_id, channel_name: channel_name)
      .where.not(id: id)
      .left_joins(:successor)
      .where(successor: { id: nil })
      .order(created_at: :desc)
      .first

    return unless predecessor_channel

    update_columns(
      predecessor_id: predecessor_channel.id,
      priority: predecessor_channel.priority,
      interaction_description: predecessor_channel.interaction_description
    )
  end

  def channel_name_unresolved?
    channel_name.blank? || channel_name == channel_id
  end

  def populate_channel_name
    client = workspace.slack_client
    info = client.conversations_info(channel: channel_id)
    channel = info.channel

    self.channel_name = resolve_im_name(client, channel) ||
      resolve_mpim_name(client, channel) ||
      channel.name.presence ||
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
