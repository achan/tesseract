class RemoteControlSessionsController < ApplicationController
  def create
    # Stop any existing active session first
    RemoteControlSession.active.find_each(&:stop!)

    RemoteControlSession.create!
    redirect_to settings_path
  end

  def destroy
    session = RemoteControlSession.find(params[:id])
    session.stop!
    redirect_to settings_path
  end
end
