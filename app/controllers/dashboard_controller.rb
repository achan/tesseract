class DashboardController < ApplicationController
  def index
    @live_activities = LiveActivity.visible

    @action_items = ActionItem
      .untriaged_items
      .where(source_type: "SlackChannel")
      .order(priority: :asc, created_at: :asc)

    @overview = Overview.order(created_at: :desc).first

    @events = SlackEvent
      .messages
      .joins(:slack_channel).where(slack_channels: { hidden: false })
      .includes(slack_channel: :workspace)
      .where("slack_events.created_at > ?", 5.hours.ago)
      .order(created_at: :desc)
  end
end
