class DashboardController < ApplicationController
  def index
    @events = SlackEvent
      .messages
      .includes(slack_channel: :workspace)
      .order(created_at: :desc)
      .limit(100)
  end
end
