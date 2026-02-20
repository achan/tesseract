class SlackChannelsController < ApplicationController
  before_action :set_workspace
  before_action :set_slack_channel, only: [:show, :edit, :update, :destroy, :toggle_hidden, :toggle_actionable]

  def show
    @events = @channel.all_slack_events.order(created_at: :desc).limit(50)
    @summary = @channel.all_summaries.order(created_at: :desc).first
    @action_items = @summary&.action_items&.order(created_at: :asc) || ActionItem.none
    @workspaces = Workspace.includes(:slack_channels).all
  end

  def edit
  end

  def update
    if @channel.update(slack_channel_params)
      redirect_to workspace_slack_channel_path(@workspace, @channel), notice: "Channel updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @channel.destroy
    redirect_to root_path, notice: "Channel removed."
  end

  def toggle_hidden
    @channel.update!(hidden: !@channel.hidden?)
    respond_to do |format|
      format.turbo_stream { render turbo_stream: turbo_stream.replace("channel_star_#{@channel.id}", partial: "slack_channels/star", locals: { workspace: @workspace, channel: @channel }) }
      format.html { redirect_to settings_path }
    end
  end

  def toggle_actionable
    @channel.update!(actionable: !@channel.actionable?)
    respond_to do |format|
      format.turbo_stream { render turbo_stream: turbo_stream.replace("channel_actionable_#{@channel.id}", partial: "slack_channels/actionable", locals: { workspace: @workspace, channel: @channel }) }
      format.html { redirect_to workspace_slack_channel_path(@workspace, @channel) }
    end
  end

  private

  def set_workspace
    @workspace = Workspace.find(params[:workspace_id])
  end

  def set_slack_channel
    @channel = @workspace.slack_channels.find(params[:id])
  end

  def slack_channel_params
    params.require(:slack_channel).permit(:channel_id, :channel_name, :priority, :interaction_description)
  end
end
