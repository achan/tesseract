class DashboardController < ApplicationController
  def index
    @live_activities = LiveActivity.visible

    @action_items = ActionItem
      .active
      .where(status: ActionItem::DASHBOARD_STATUSES)
      .order(
        Arel.sql("CASE status WHEN 'untriaged' THEN 0 WHEN 'todo' THEN 1 END"),
        priority: :asc,
        created_at: :asc
      )

    @overview = Overview.order(created_at: :desc).first

    @events = SlackEvent
      .messages
      .joins(:slack_channel).where(slack_channels: { hidden: false })
      .includes(slack_channel: :workspace)
      .where("slack_events.created_at > ?", 5.hours.ago)
      .order(created_at: :desc)
  end
end
