class Workspace < ApplicationRecord
  encrypts :user_token

  belongs_to :profile
  has_many :slack_channels, dependent: :destroy
  has_many :feed_sources, as: :source, dependent: :destroy

  validates :team_name, presence: true

  before_save :populate_team_id, if: -> { user_token_changed? && user_token.present? }

  def resolve_user_name(user_id)
    resolve_user_profile(user_id)[:name]
  end

  def resolve_user_avatar(user_id)
    resolve_user_profile(user_id)[:avatar]
  end

  def resolve_user_profile(user_id)
    return { name: user_id, avatar: nil } if user_id.blank? || user_token.blank?

    Rails.cache.fetch("slack_user_profile/#{id}/#{user_id}", expires_in: 1.hour) do
      info = slack_client.users_info(user: user_id)
      {
        name: info.user.real_name.presence || info.user.name.presence || user_id,
        handle: info.user.name,
        avatar: info.user.profile.image_32.presence || info.user.profile.image_24.presence
      }
    end
  rescue Slack::Web::Api::Errors::SlackError, Faraday::Error
    { name: user_id, handle: nil, avatar: nil }
  end

  def resolve_bot_profile(bot_id)
    return { name: bot_id, avatar: nil } if bot_id.blank? || user_token.blank?

    Rails.cache.fetch("slack_bot_profile/#{id}/#{bot_id}", expires_in: 1.hour) do
      info = slack_client.bots_info(bot: bot_id)
      icons = info.bot.icons.to_h
      {
        name: info.bot.name.presence || bot_id,
        avatar: icons["image_36"].presence || icons["image_48"].presence
      }
    end
  rescue Slack::Web::Api::Errors::SlackError, Faraday::Error
    { name: bot_id, avatar: nil }
  end

  def authenticated_user_id
    return if user_token.blank?

    Rails.cache.fetch("workspace_#{id}_auth_user_id", expires_in: 1.hour) do
      slack_client.auth_test.user_id
    end
  rescue Slack::Web::Api::Errors::SlackError, Faraday::Error
    nil
  end

  def owner_identity_context
    uid = authenticated_user_id
    return nil if uid.blank?

    slack_profile = resolve_user_profile(uid)
    handle_part = slack_profile[:handle].present? ? ", handle: @#{slack_profile[:handle]}" : ""
    context = "You are analyzing these messages on behalf of #{slack_profile[:name]} (Slack user ID: #{uid}#{handle_part}). " \
      "When messages mention <@#{uid}> or reference #{slack_profile[:name]}, they are addressed to this user."

    if profile.role_context.present?
      context += "\n\nRole & Responsibilities: #{profile.role_context}"
    end

    context
  end

  def slack_client
    Slack::Web::Client.new(token: user_token)
  end

  private

  def populate_team_id
    response = slack_client.auth_test
    self.team_id = response.team_id
  rescue Slack::Web::Api::Errors::SlackError, Faraday::Error
    # Leave team_id blank if the API call fails
  end
end
