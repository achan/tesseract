module Api
  class LiveActivitiesController < ApplicationController
    skip_before_action :verify_authenticity_token
    skip_before_action :authenticate
    skip_forgery_protection

    def index
      render json: LiveActivity.visible
    end

    def start
      activity = LiveActivity.find_or_initialize_by(
        activity_type: params[:activity_type],
        activity_id: params[:activity_id]
      )
      activity.assign_attributes(
        title: params[:title],
        subtitle: params[:subtitle],
        metadata: params[:metadata] || {},
        status: "active",
        ends_at: nil
      )
      activity.save!
      render json: activity, status: :ok
    end

    def progress
      activity = LiveActivity.find_by!(
        activity_type: params[:activity_type],
        activity_id: params[:activity_id]
      )
      activity.subtitle = params[:subtitle] if params[:subtitle].present?
      if params[:metadata].present?
        activity.metadata = activity.metadata.merge(params[:metadata].to_unsafe_h)
      end
      activity.save!
      render json: activity, status: :ok
    end

    def stop
      activity = LiveActivity.find_by!(
        activity_type: params[:activity_type],
        activity_id: params[:activity_id]
      )
      activity.update!(status: "ending", ends_at: 10.seconds.from_now)
      LiveActivityCleanupJob.set(wait: 10.seconds).perform_later(activity.id)
      render json: activity, status: :ok
    end
  end
end
