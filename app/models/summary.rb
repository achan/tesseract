class Summary < ApplicationRecord
  belongs_to :source, polymorphic: true
  has_many :action_items, dependent: :destroy

  after_create_commit :broadcast_summary

  private

  def broadcast_summary
    return unless source.is_a?(SlackChannel)

    broadcast_replace_to(
      "workspace_#{source.workspace_id}_channel_#{source.channel_id}_summary",
      target: "latest_summary",
      partial: "summaries/summary",
      locals: { summary: self }
    )
  end
end
