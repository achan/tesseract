class ActionItemsController < ApplicationController
  def index
    @action_items = ActionItem
      .where(source_type: "SlackChannel")
      .includes(source: :workspace)
      .order(Arel.sql("CASE status WHEN 'open' THEN 0 WHEN 'done' THEN 1 WHEN 'dismissed' THEN 2 END"), created_at: :desc)
  end

  def update
    @action_item = ActionItem.find(params[:id])
    @action_item.update!(action_item_params)

    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: turbo_stream.replace(
          "action_item_#{@action_item.id}",
          partial: "action_items/action_item",
          locals: { action_item: @action_item }
        )
      end
      format.html { redirect_back fallback_location: root_path }
    end
  end

  private

  def action_item_params
    params.require(:action_item).permit(:status)
  end
end
