class DailySummarizeJob < ApplicationJob
  queue_as :default

  def perform
    Workspace.find_each do |workspace|
      workspace.slack_channels.find_each do |channel|
        last_summary_end = channel.all_summaries.maximum(:period_end)
        cutoff = last_summary_end || 24.hours.ago

        next unless channel.slack_events.where("created_at > ?", cutoff).exists?

        SummarizeJob.perform_later(
          workspace_id: workspace.id,
          channel_id: channel.channel_id
        )
      end
    end
  end
end
