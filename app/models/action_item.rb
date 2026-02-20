class ActionItem < ApplicationRecord
  belongs_to :summary, optional: true
  belongs_to :source, polymorphic: true

  validates :description, presence: true
  validates :status, presence: true, inclusion: { in: %w[open done dismissed] }
  validates :priority, inclusion: { in: 1..5 }

  scope :open_items, -> { where(status: "open") }

  after_create_commit :broadcast_append, :broadcast_dashboard_append
  after_update_commit :broadcast_replace, :broadcast_dashboard_remove

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
    return unless source.is_a?(SlackChannel) && status == "open"

    broadcast_append_to(
      "dashboard_action_items",
      target: "dashboard_action_items",
      partial: "dashboard/action_item",
      locals: { action_item: self }
    )
  end

  def broadcast_dashboard_remove
    return unless source.is_a?(SlackChannel) && status != "open"

    broadcast_remove_to("dashboard_action_items", target: "dashboard_action_item_#{id}")
  end

  def dom_id(record)
    "action_item_#{record.id}"
  end
end
