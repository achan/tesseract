class ActionItem < ApplicationRecord
  STATUSES = %w[untriaged backlog todo in_progress done wont_fix].freeze
  KANBAN_COLUMNS = %w[untriaged backlog todo in_progress done wont_fix].freeze
  DASHBOARD_STATUSES = %w[untriaged todo].freeze

  belongs_to :summary, optional: true
  belongs_to :source, polymorphic: true, optional: true

  validates :description, presence: true
  validates :status, presence: true, inclusion: { in: STATUSES }
  validates :priority, inclusion: { in: 1..5 }

  STATUS_LABELS = {
    "todo" => "To Do",
    "wont_fix" => "Won't Fix"
  }.freeze

  scope :untriaged, -> { where(status: "untriaged") }
  scope :active, -> { where(archived_at: nil) }
  scope :archived, -> { where.not(archived_at: nil) }

  def status_label
    STATUS_LABELS[status] || status.titleize
  end

  def archive!
    update!(archived_at: Time.current)
  end

  def unarchive!
    update!(archived_at: nil)
  end

  def archived?
    archived_at.present?
  end

  after_create_commit :broadcast_append, :broadcast_dashboard_append, :broadcast_kanban_append
  after_update_commit :broadcast_replace, :broadcast_dashboard_update, :broadcast_kanban_move, :broadcast_kanban_archive

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

  def broadcast_kanban_append
    broadcast_append_to(
      "kanban_action_items",
      target: "kanban_column_#{status}",
      partial: "action_items/action_item",
      locals: { action_item: self }
    )
  end

  def broadcast_kanban_move
    return if archived?
    return unless saved_change_to_status?

    broadcast_remove_to("kanban_action_items", target: "action_item_#{id}")
    broadcast_append_to(
      "kanban_action_items",
      target: "kanban_column_#{status}",
      partial: "action_items/action_item",
      locals: { action_item: self }
    )
  end

  def broadcast_kanban_archive
    return unless saved_change_to_archived_at?

    if archived?
      broadcast_remove_to("kanban_action_items", target: "action_item_#{id}")
    else
      broadcast_append_to(
        "kanban_action_items",
        target: "kanban_column_#{status}",
        partial: "action_items/action_item",
        locals: { action_item: self }
      )
    end
  end

  def dom_id(record)
    "action_item_#{record.id}"
  end
end
