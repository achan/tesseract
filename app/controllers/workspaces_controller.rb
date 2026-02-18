class WorkspacesController < ApplicationController
  before_action :set_workspace, only: [:edit, :update, :destroy]

  def new
    @workspace = Workspace.new
  end

  def create
    @workspace = Workspace.new(workspace_params)
    if @workspace.save
      redirect_to root_path, notice: "Workspace created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @workspace.update(workspace_params)
      redirect_to root_path, notice: "Workspace updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @workspace.destroy
    redirect_to root_path, notice: "Workspace deleted."
  end

  private

  def set_workspace
    @workspace = Workspace.find(params[:id])
  end

  def workspace_params
    params.require(:workspace).permit(:team_id, :team_name, :user_token, :signing_secret)
  end
end
