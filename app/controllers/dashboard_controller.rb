class DashboardController < ApplicationController
  EVENTS_PER_PAGE = 50

  def index
    @live_activities = LiveActivity.visible

    @action_items = ActionItem
      .active
      .where(status: ActionItem::DASHBOARD_STATUSES)
      .where(
        "(source_type = 'SlackChannel' AND source_id IN (?)) OR (source_type = 'Profile' AND source_id IN (?))",
        active_slack_channel_ids, active_profile_ids
      )
      .order(
        Arel.sql("CASE status WHEN 'untriaged' THEN 0 WHEN 'todo' THEN 1 END"),
        priority: :asc,
        created_at: :asc
      )

    @overview = pick_overview

    events_scope = events_scope()
    @events = events_scope.limit(EVENTS_PER_PAGE)
    @has_more_events = events_scope.limit(EVENTS_PER_PAGE + 1).count > EVENTS_PER_PAGE
  end

  def events
    scope = events_scope
    scope = scope.where("slack_events.created_at < ?", Time.parse(params[:before])) if params[:before].present?
    @events = scope.limit(EVENTS_PER_PAGE)
    @has_more = scope.limit(EVENTS_PER_PAGE + 1).count > EVENTS_PER_PAGE
  end

  private

  def pick_overview
    enabled_profiles = Profile.where(enabled: true)
    scope = if enabled_profiles.count == 1
      Overview.where(profile_id: enabled_profiles.first.id)
    else
      Overview.where(profile_id: nil)
    end
    scope.order(created_at: :desc).first
  end

  def events_scope
    SlackEvent
      .messages
      .joins(:slack_channel).where(slack_channels: { hidden: false, workspace_id: active_workspace_ids })
      .includes(slack_channel: :workspace)
      .order(created_at: :desc)
  end
end
