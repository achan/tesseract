class OverviewsController < ApplicationController
  def create
    GenerateOverviewJob.perform_later
    head :ok
  end
end
