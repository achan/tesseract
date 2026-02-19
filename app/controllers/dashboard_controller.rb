class DashboardController < ApplicationController
  def index
    @events = SlackEvent
      .messages
      .joins(:slack_channel).where(slack_channels: { hidden: false })
      .includes(slack_channel: :workspace)
      .where("slack_events.created_at > ?", 5.hours.ago)
      .order(created_at: :desc)
  end
end
