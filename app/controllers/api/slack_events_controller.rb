module Api
  class SlackEventsController < ApplicationController
    skip_before_action :verify_authenticity_token
    before_action :find_workspace_and_verify_signature, unless: :url_verification?

    def create
      if url_verification?
        return render json: { challenge: parsed_payload["challenge"] }
      end

      event = parsed_payload["event"]
      return head :ok unless event

      channel_id = event["channel"] || event.dig("item", "channel")
      return head :ok unless channel_id

      slack_channel = @workspace.slack_channels.find_by(channel_id: channel_id, active: true)
      slack_channel ||= auto_track_direct_conversation(channel_id, event["channel_type"])
      return head :ok unless slack_channel

      event_id = parsed_payload["event_id"]
      return head :ok unless event_id

      SlackEvent.create_or_find_by(event_id: event_id) do |e|
        e.slack_channel = slack_channel
        e.event_type = event["type"]
        e.user_id = event["user"]
        e.ts = event["ts"]
        e.thread_ts = event["thread_ts"]
        e.payload = event
      end

      head :ok
    end

    private

    def find_workspace_and_verify_signature
      timestamp = request.headers["X-Slack-Request-Timestamp"]
      return head :unauthorized if timestamp.blank?
      return head :unauthorized if (Time.now.to_i - timestamp.to_i).abs > 300

      channel_id = parsed_payload.dig("event", "channel") || parsed_payload.dig("event", "item", "channel")
      slack_channel = SlackChannel.find_by(channel_id: channel_id, active: true) if channel_id

      if slack_channel
        @workspace = slack_channel.workspace
        return head :unauthorized unless valid_signature?(@workspace.signing_secret)
      else
        @workspace = Workspace.find_each.find { |w| valid_signature?(w.signing_secret) }
        return head :unauthorized unless @workspace
      end
    end

    def valid_signature?(signing_secret)
      return false if signing_secret.blank?

      sig_basestring = "v0:#{request.headers["X-Slack-Request-Timestamp"]}:#{request_body}"
      computed = "v0=#{OpenSSL::HMAC.hexdigest("SHA256", signing_secret, sig_basestring)}"
      ActiveSupport::SecurityUtils.secure_compare(computed, request.headers["X-Slack-Signature"].to_s)
    end

    def url_verification?
      parsed_payload["type"] == "url_verification"
    end

    def request_body
      @_raw_body ||= begin
        request.body.rewind
        body = request.body.read
        request.body.rewind
        body
      end
    end

    def parsed_payload
      @_parsed_payload ||= JSON.parse(request_body)
    end

    def auto_track_direct_conversation(channel_id, channel_type)
      return unless %w[im mpim].include?(channel_type)

      case channel_type
      when "im"
        return unless @workspace.include_dms
      when "mpim"
        return unless @workspace.include_mpims
      end

      @workspace.slack_channels.find_or_create_by(channel_id: channel_id) do |c|
        c.channel_name = channel_id
      end
    end
  end
end
