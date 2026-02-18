module Api
  class SlackEventsController < ApplicationController
    include SlackSignatureVerification

    skip_before_action :verify_authenticity_token
    before_action :verify_slack_signature, unless: :url_verification?

    def create
      payload = parsed_payload

      if url_verification?
        return render json: { challenge: payload["challenge"] }
      end

      workspace = Workspace.find_by(team_id: payload["team_id"])
      return head :ok unless workspace

      event = payload["event"]
      return head :ok unless event

      channel_id = event["channel"] || event.dig("item", "channel")
      return head :ok unless channel_id
      return head :ok unless workspace.active_channel_ids.include?(channel_id)

      slack_channel = workspace.slack_channels.find_by!(channel_id: channel_id)
      event_id = payload["event_id"]
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

    def url_verification?
      parsed_payload["type"] == "url_verification"
    end
  end
end
