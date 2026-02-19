class LiveActivitiesController < ApplicationController
  def destroy
    activity = LiveActivity.find(params[:id])
    activity.broadcast_remove_to("dashboard_live_activities", target: "live_activity_#{activity.id}")
    activity.destroy

    respond_to do |format|
      format.turbo_stream { head :ok }
      format.html { redirect_to root_path }
    end
  end
end
