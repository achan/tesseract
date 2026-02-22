class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  before_action :authenticate

  private

  def authenticate
    return unless http_basic_auth_configured?
    return if valid_auth_cookie?

    authenticate_or_request_with_http_basic do |username, password|
      valid = ActiveSupport::SecurityUtils.secure_compare(username, ENV["HTTP_BASIC_AUTH_USERNAME"]) &
        ActiveSupport::SecurityUtils.secure_compare(password, ENV["HTTP_BASIC_AUTH_PASSWORD"])
      set_auth_cookie if valid
      valid
    end
  end

  def valid_auth_cookie?
    cookies.encrypted[:authenticated] == "1"
  end

  def set_auth_cookie
    cookies.encrypted[:authenticated] = { value: "1", expires: 30.days, httponly: true, same_site: :lax }
  end

  def http_basic_auth_configured?
    ENV["HTTP_BASIC_AUTH_USERNAME"].present? && ENV["HTTP_BASIC_AUTH_PASSWORD"].present?
  end
  helper_method :http_basic_auth_configured?

  def active_profile_ids
    @active_profile_ids ||= Profile.where(enabled: true).pluck(:id)
  end
  helper_method :active_profile_ids

  def active_workspace_ids
    @active_workspace_ids ||= Workspace.where(profile_id: active_profile_ids).pluck(:id)
  end
  helper_method :active_workspace_ids

  def active_slack_channel_ids
    @active_slack_channel_ids ||= SlackChannel.where(workspace_id: active_workspace_ids).pluck(:id)
  end
  helper_method :active_slack_channel_ids
end
