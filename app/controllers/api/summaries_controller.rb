module Api
  class SummariesController < ApplicationController
    skip_before_action :verify_authenticity_token
    skip_before_action :authenticate

    def generate
      workspace_id = params[:workspace_id]
      channel_id = params[:channel_id]

      unless workspace_id.present? && channel_id.present?
        return render json: { error: "workspace_id and channel_id are required" }, status: :unprocessable_entity
      end

      SummarizeJob.perform_later(
        workspace_id: workspace_id.to_i,
        channel_id: channel_id
      )

      head :accepted
    end
  end
end
