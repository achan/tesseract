class SlackChannelsController < ApplicationController
  before_action :set_workspace
  before_action :set_slack_channel, only: [:show, :edit, :update, :destroy, :toggle_hidden, :toggle_actionable, :events]

  def show
    events_scope = @channel.all_slack_events.order(created_at: :desc)
    @events = events_scope.limit(EVENTS_PER_PAGE)
    @has_more_events = events_scope.limit(EVENTS_PER_PAGE + 1).count > EVENTS_PER_PAGE
    @summaries = @channel.all_summaries.order(created_at: :desc)
    @summary = @summaries.first
    @action_items = @channel.all_action_items.active.where(status: %w[todo done]).order(created_at: :asc)
    @workspaces = Workspace.includes(:slack_channels).where(id: active_workspace_ids)
  end

  EVENTS_PER_PAGE = 50

  def events
    scope = @channel.all_slack_events.order(created_at: :desc)
    scope = scope.where("slack_events.created_at < ?", Time.parse(params[:before])) if params[:before].present?
    @events = scope.limit(EVENTS_PER_PAGE)
    @has_more = scope.limit(EVENTS_PER_PAGE + 1).count > EVENTS_PER_PAGE
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
