class SettingsController < ApplicationController
  def show
  end

  def logout
    cookies.delete(:authenticated)
    head :unauthorized
  end
end
