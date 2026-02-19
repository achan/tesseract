class GenerateActionItemsJob < ApplicationJob
  queue_as :default

  def perform(slack_event_id:)
    event = SlackEvent.find_by(id: slack_event_id)
    return unless event

    channel = event.slack_channel
    latest_event = channel.slack_events.order(created_at: :desc).pick(:id)
    return unless latest_event == event.id

    SummarizeJob.perform_now(
      workspace_id: channel.workspace_id,
      channel_id: channel.channel_id
    )
  end
end
