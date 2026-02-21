class ActionItem < ApplicationRecord
  STATUSES = %w[untriaged backlog todo in_progress done wont_fix].freeze
  KANBAN_COLUMNS = %w[untriaged backlog todo in_progress done wont_fix].freeze
  DASHBOARD_STATUSES = %w[untriaged todo].freeze

  belongs_to :summary, optional: true
  belongs_to :source, polymorphic: true

  validates :description, presence: true
  validates :status, presence: true, inclusion: { in: STATUSES }
  validates :priority, inclusion: { in: 1..5 }

  STATUS_LABELS = {
    "todo" => "To Do",
    "wont_fix" => "Won't Fix"
  }.freeze

  scope :untriaged, -> { where(status: "untriaged") }

  def status_label
    STATUS_LABELS[status] || status.titleize
  end

  after_create_commit :broadcast_append, :broadcast_dashboard_append
  after_update_commit :broadcast_replace, :broadcast_dashboard_update, :broadcast_kanban_move

  private

  def broadcast_append
    return unless source.is_a?(SlackChannel)

    broadcast_append_to(
      "workspace_#{source.workspace_id}_channel_#{source.channel_id}_action_items",
      target: "action_items",
      partial: "action_items/action_item",
      locals: { action_item: self }
    )
  end

  def broadcast_replace
    return unless source.is_a?(SlackChannel)

    broadcast_replace_to(
      "workspace_#{source.workspace_id}_channel_#{source.channel_id}_action_items",
      target: dom_id(self),
      partial: "action_items/action_item",
      locals: { action_item: self }
    )
  end

  def broadcast_dashboard_append
    return unless source.is_a?(SlackChannel) && status.in?(DASHBOARD_STATUSES)

    broadcast_append_to(
      "dashboard_action_items",
      target: "dashboard_action_items",
      partial: "dashboard/action_item",
      locals: { action_item: self }
    )
  end

  def broadcast_dashboard_update
    return unless source.is_a?(SlackChannel)

    if status.in?(DASHBOARD_STATUSES)
      broadcast_replace_to(
        "dashboard_action_items",
        target: "dashboard_action_item_#{id}",
        partial: "dashboard/action_item",
        locals: { action_item: self }
      )
    else
      broadcast_remove_to("dashboard_action_items", target: "dashboard_action_item_#{id}")
    end
  end

  def broadcast_kanban_move
    return unless source.is_a?(SlackChannel) && saved_change_to_status?

    old_status = status_before_last_save
    broadcast_remove_to("kanban_action_items", target: "action_item_#{id}")
    broadcast_append_to(
      "kanban_action_items",
      target: "kanban_column_#{status}",
      partial: "action_items/action_item",
      locals: { action_item: self }
    )
  end

  def dom_id(record)
    "action_item_#{record.id}"
  end
end
