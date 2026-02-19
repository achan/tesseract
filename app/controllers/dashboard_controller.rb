class DashboardController < ApplicationController
  def index
    @events = SlackEvent
      .messages
      .joins(:slack_channel).where(slack_channels: { hidden: false })
      .includes(slack_channel: :workspace)
      .order(created_at: :desc)
      .limit(100)
  end
end
