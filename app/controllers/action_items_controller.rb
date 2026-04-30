class ActionItemsController < ApplicationController
  def index
    scope = params[:archived] == "true" ? ActionItem.archived : ActionItem.active
    @archived = params[:archived] == "true"

    @action_items = scope
      .where(active_source_predicate, active_slack_channel_ids, active_profile_ids, active_slack_channel_ids)
      .order(priority: :asc, created_at: :desc)

    @columns = ActionItem::KANBAN_COLUMNS.map do |status|
      [status, @action_items.select { |i| i.status == status }]
    end
  end

  def new
    @action_item = ActionItem.new(source_type: "Profile", status: params[:status] || "untriaged", priority: 3)
    assign_requested_source(@action_item)

    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: turbo_stream.update(
          "action_item_modal_content",
          partial: "action_items/form",
          locals: { action_item: @action_item }
        )
      end
    end
  end

  def create
    @action_item = ActionItem.new(action_item_params)

    respond_to do |format|
      if @action_item.save
        format.turbo_stream do
          render turbo_stream: turbo_stream.append(
            "kanban_column_#{@action_item.status}",
            partial: "action_items/action_item",
            locals: { action_item: @action_item }
          )
        end
      else
        format.turbo_stream do
          render turbo_stream: turbo_stream.update(
            "action_item_modal_content",
            partial: "action_items/form",
            locals: { action_item: @action_item }
          ), status: :unprocessable_entity
        end
      end
    end
  end

  def edit
    @action_item = ActionItem.find(params[:id])

    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: turbo_stream.update(
          "action_item_modal_content",
          partial: "action_items/form",
          locals: { action_item: @action_item }
        )
      end
    end
  end

  def update
    @action_item = ActionItem.find(params[:id])

    respond_to do |format|
      if @action_item.update(action_item_params)
        format.turbo_stream do
          streams = []
          streams << turbo_stream.replace(
            "action_item_#{@action_item.id}",
            partial: "action_items/action_item",
            locals: { action_item: @action_item }
          )
          render turbo_stream: streams
        end
        format.html { redirect_back fallback_location: root_path }
      else
        format.turbo_stream do
          render turbo_stream: turbo_stream.update(
            "action_item_modal_content",
            partial: "action_items/form",
            locals: { action_item: @action_item }
          ), status: :unprocessable_entity
        end
        format.html { redirect_back fallback_location: root_path }
      end
    end
  end

  def archive
    @action_item = ActionItem.find(params[:id])
    @action_item.archive!

    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: turbo_stream.remove("action_item_#{@action_item.id}")
      end
      format.html { redirect_back fallback_location: action_items_path }
    end
  end

  def unarchive
    @action_item = ActionItem.find(params[:id])
    @action_item.unarchive!

    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: turbo_stream.remove("action_item_#{@action_item.id}")
      end
      format.html { redirect_back fallback_location: action_items_path(archived: true) }
    end
  end

  private

  def action_item_params
    params.require(:action_item).permit(:description, :priority, :assignee_user_id, :status, :source_id, :source_type, :source_ts)
  end

  def assign_requested_source(action_item)
    source_type = params[:source_type].presence
    source_id = params[:source_id].presence
    return if source_type.blank? || source_id.blank?

    source = find_source(source_type, source_id)
    return unless source

    action_item.source = source
    action_item.source_ts = params[:source_ts].presence if params[:source_ts].present?
  end

  def find_source(source_type, source_id)
    case source_type
    when "Profile"
      Profile.find_by(id: source_id)
    when "SlackChannel"
      SlackChannel.find_by(id: source_id)
    when "SlackEvent"
      SlackEvent.find_by(id: source_id)
    end
  end

  def active_source_predicate
    <<~SQL.squish
      (source_type = 'SlackChannel' AND source_id IN (?))
      OR (source_type = 'Profile' AND source_id IN (?))
      OR (
        source_type = 'SlackEvent'
        AND source_id IN (
          SELECT id FROM slack_events WHERE slack_channel_id IN (?)
        )
      )
    SQL
  end
end
