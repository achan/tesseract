class SummarizeJob < ApplicationJob
  queue_as :default

  def perform(workspace_id:, channel_id:, period_start: nil, period_end: Time.current)
    workspace = Workspace.find(workspace_id)
    channel = workspace.slack_channels.find_by!(channel_id: channel_id)

    start_live_activity(
      activity_type: "summarize",
      activity_id: channel_id,
      title: "Summarizing",
      subtitle: "##{channel.channel_name}"
    )

    period_start ||= channel.all_summaries.maximum(:period_end) || 24.hours.ago
    events = channel.slack_events
      .in_window(period_start, period_end)
      .order(:created_at)

    if events.empty?
      stop_live_activity(subtitle: "No recent messages")
      return
    end

    grouped = group_by_thread(events)
    prompt = build_prompt(grouped, channel)

    update_live_activity(subtitle: "Calling Claude...")

    summary_text = call_claude(prompt)

    Summary.create!(
      source: channel,
      period_start: period_start,
      period_end: period_end,
      summary_text: summary_text,
      model_used: "claude-cli"
    )

    stop_live_activity
  end

  private

  def call_claude(prompt)
    output, status = Open3.capture2(
      { "CLAUDECODE" => nil, "ANTHROPIC_API_KEY" => nil },
      "claude", "-p",
      "--output-format", "text",
      stdin_data: prompt
    )
    raise "claude CLI failed (exit #{status.exitstatus}): #{output}" unless status.success?
    output.strip
  end

  def group_by_thread(events)
    threads = {}
    top_level = []

    events.each do |event|
      if event.thread_ts.present? && event.thread_ts != event.ts
        threads[event.thread_ts] ||= []
        threads[event.thread_ts] << event
      else
        top_level << event
      end
    end

    { top_level: top_level, threads: threads }
  end

  def build_prompt(grouped, channel)
    lines = ["Summarize the following Slack channel activity."]
    lines << ""
    lines << "Return ONLY the summary text, no JSON, no markdown fences."
    lines << ""
    lines << "## Channel Context"
    lines << "Priority: #{channel.priority} (1=highest, 5=lowest)"
    lines << "Interaction description: #{channel.interaction_description}" if channel.interaction_description.present?
    lines << ""
    lines << "## Messages"
    lines << ""

    append_messages(lines, grouped)
    lines.join("\n")
  end

  MAX_PROMPT_CHARS = 100_000

  def append_messages(lines, grouped)
    budget = MAX_PROMPT_CHARS - lines.sum(&:length)
    message_lines = []

    grouped[:top_level].reverse_each do |event|
      entry_lines = []
      text = event.payload.is_a?(Hash) ? event.payload["text"] : ""
      entry_lines << "[#{event.ts}] #{event.user_id}: #{text}"

      thread_replies = grouped[:threads][event.ts]
      if thread_replies
        thread_replies.each do |reply|
          reply_text = reply.payload.is_a?(Hash) ? reply.payload["text"] : ""
          entry_lines << "  [#{reply.ts}] #{reply.user_id}: #{reply_text}"
        end
      end

      entry_size = entry_lines.sum(&:length) + entry_lines.size
      break if entry_size > budget

      budget -= entry_size
      message_lines.concat(entry_lines)
    end

    lines.concat(message_lines.reverse)
  end
end
