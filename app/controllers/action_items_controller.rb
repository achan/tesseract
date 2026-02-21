class ActionItemsController < ApplicationController
  def index
    all_items = ActionItem
      .where(source_type: "SlackChannel")
      .includes(source: :workspace)
      .order(priority: :asc, created_at: :desc)

    @columns = ActionItem::STATUSES.map { |status| [status, all_items.select { |i| i.status == status }] }
  end

  def update
    @action_item = ActionItem.find(params[:id])
    old_status = @action_item.status
    @action_item.update!(action_item_params)

    respond_to do |format|
      format.turbo_stream do
        streams = []
        streams << turbo_stream.remove("action_item_#{@action_item.id}")
        streams << turbo_stream.append(
          "kanban_column_#{@action_item.status}",
          partial: "action_items/action_item",
          locals: { action_item: @action_item }
        )
        render turbo_stream: streams
      end
      format.html { redirect_back fallback_location: root_path }
    end
  end

  private

  def action_item_params
    params.require(:action_item).permit(:status)
  end
end
