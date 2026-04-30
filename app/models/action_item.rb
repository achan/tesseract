class ActionItem < ApplicationRecord
  STATUSES = %w[untriaged backlog todo in_progress done wont_fix].freeze
  KANBAN_COLUMNS = %w[untriaged backlog todo in_progress done wont_fix].freeze
  DASHBOARD_STATUSES = %w[untriaged in_progress todo].freeze

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

  def source_channel
    case source
    when SlackChannel
      source
    when SlackEvent
      source.slack_channel
    end
  end

  def source_label
    case source
    when Profile
      source.name
    when SlackChannel
      "##{source.display_name}"
    when SlackEvent
      "Message in ##{source.slack_channel.display_name}"
    end
  end

  after_create_commit :broadcast_append, :broadcast_dashboard_append, :broadcast_kanban_append
  after_update_commit :broadcast_replace, :broadcast_dashboard_update, :broadcast_kanban_move, :broadcast_kanban_archive

  private

  def broadcast_append
    channel = source_channel
    return unless channel

    broadcast_append_to(
      "workspace_#{channel.workspace_id}_channel_#{channel.channel_id}_action_items",
      target: "action_items",
      partial: "action_items/action_item",
      locals: { action_item: self }
    )
  end

  def broadcast_replace
    channel = source_channel
    return unless channel

    broadcast_replace_to(
      "workspace_#{channel.workspace_id}_channel_#{channel.channel_id}_action_items",
      target: dom_id(self),
      partial: "action_items/action_item",
      locals: { action_item: self }
    )
  end

  def broadcast_dashboard_append
    return unless source_channel && status.in?(DASHBOARD_STATUSES) && !archived?

    broadcast_append_to(
      "dashboard_action_items",
      target: "dashboard_action_items",
      partial: "dashboard/action_item",
      locals: { action_item: self }
    )
  end

  def broadcast_dashboard_update
    previously_visible = previous_dashboard_status.in?(DASHBOARD_STATUSES) && !archived_at_before_last_save.present?
    now_visible = status.in?(DASHBOARD_STATUSES) && !archived?

    if now_visible && previously_visible
      broadcast_replace_to(
        "dashboard_action_items",
        target: "dashboard_action_item_#{id}",
        partial: "dashboard/action_item",
        locals: { action_item: self }
      )
    elsif now_visible
      broadcast_append_to(
        "dashboard_action_items",
        target: "dashboard_action_items",
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

  def previous_dashboard_status
    saved_change_to_status? ? status_before_last_save : status
  end

  def dom_id(record)
    "action_item_#{record.id}"
  end
end
