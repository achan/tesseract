class ActionItem < ApplicationRecord
  belongs_to :summary
  belongs_to :source, polymorphic: true

  validates :description, presence: true
  validates :status, presence: true, inclusion: { in: %w[open done dismissed] }

  scope :open_items, -> { where(status: "open") }

  after_create_commit :broadcast_append
  after_update_commit :broadcast_replace

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

  def dom_id(record)
    "action_item_#{record.id}"
  end
end
