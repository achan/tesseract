class OverviewsController < ApplicationController
  def create
    GenerateOverviewJob.perform_later(profile_id: nil)
    Profile.find_each do |profile|
      GenerateOverviewJob.perform_later(profile_id: profile.id)
    end
    head :no_content
  end
end
