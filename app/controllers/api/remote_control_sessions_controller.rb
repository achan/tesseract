module Api
  class RemoteControlSessionsController < ApplicationController
    skip_before_action :verify_authenticity_token
    skip_before_action :authenticate

    def started
      session = RemoteControlSession.find(params[:id])
      claude_session_id = params[:claude_session_id]
      session_url = "https://claude.ai/code/session_#{claude_session_id}" if claude_session_id.present?

      session.update!(status: "running", session_url: session_url)
      head :ok
    end

    def ended
      session = RemoteControlSession.find(params[:id])
      session.update!(status: "stopped") unless session.status == "stopped"
      head :ok
    end
  end
end
