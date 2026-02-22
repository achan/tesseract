class ProfilesController < ApplicationController
  before_action :set_profile, only: [:show, :edit, :update, :destroy, :toggle]

  def index
    redirect_to settings_path
  end

  def show
  end

  def new
    @profile = Profile.new
  end

  def create
    @profile = Profile.new(profile_params)
    if @profile.save
      redirect_to @profile, notice: "Profile created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @profile.update(profile_params)
      redirect_to @profile, notice: "Profile updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    if @profile.destroy
      redirect_to settings_path, notice: "Profile deleted."
    else
      redirect_to @profile, alert: @profile.errors.full_messages.to_sentence
    end
  end

  def toggle
    @profile.update!(enabled: !@profile.enabled?)
    respond_to do |format|
      format.turbo_stream { render turbo_stream: turbo_stream.replace("profile_toggle_#{@profile.id}", partial: "profiles/toggle", locals: { profile: @profile }) }
      format.html { redirect_to settings_path }
    end
  end

  private

  def set_profile
    @profile = Profile.find(params[:id])
  end

  def profile_params
    params.require(:profile).permit(:name)
  end
end
