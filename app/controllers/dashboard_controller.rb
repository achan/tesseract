class DashboardController < ApplicationController
  def show
    @workspaces = Workspace.includes(:slack_channels).all
  end
end
