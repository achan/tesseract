class GenerateOverviewJob < ApplicationJob
  queue_as :default

  def perform
    start_live_activity(
      activity_type: "overview",
      activity_id: "overview",
      title: "Generating overview",
      subtitle: "Collecting messages..."
    )

    events = SlackEvent
      .messages
      .joins(:slack_channel)
      .where("slack_events.created_at > ?", 1.hour.ago)
      .includes(:slack_channel)
      .order(:created_at)

    if events.empty?
      stop_live_activity(subtitle: "No recent messages")
      return
    end

    grouped_by_channel = events.group_by { |e| e.slack_channel }

    prompt = build_prompt(grouped_by_channel)

    update_live_activity(subtitle: "Calling Claude...")

    body = call_claude(prompt)

    Overview.create!(body: body, model_used: "claude-cli")

    stop_live_activity
  end

  private

  def call_claude(prompt)
    output, status = Open3.capture2(
      { "CLAUDECODE" => nil, "ANTHROPIC_API_KEY" => nil },
      "claude", "-p", prompt,
      "--output-format", "text"
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

  def build_prompt(grouped_by_channel)
    lines = ["Provide a concise cross-channel overview of the following Slack activity from the last hour."]
    lines << ""
    lines << "Start with a 1-2 sentence summary paragraph capturing the most important activity."
    lines << "Then add a blank line followed by the detailed overview."
    lines << "Highlight key themes, decisions, and items that need attention."
    lines << "Group related activity together rather than listing channel-by-channel."
    lines << "Use markdown formatting. Return ONLY the overview text."
    lines << "Exam Quality: Name the providers that are good, bad, slow, fast, etc."
    lines << ""

    grouped_by_channel.each do |channel, channel_events|
      lines << "## ##{channel.display_name}"
      lines << ""

      grouped = group_by_thread(channel_events)

      grouped[:top_level].each do |event|
        text = event.payload.is_a?(Hash) ? event.payload["text"] : ""
        lines << "[#{event.ts}] #{event.user_id}: #{text}"

        thread_replies = grouped[:threads][event.ts]
        if thread_replies
          thread_replies.each do |reply|
            reply_text = reply.payload.is_a?(Hash) ? reply.payload["text"] : ""
            lines << "  [#{reply.ts}] #{reply.user_id}: #{reply_text}"
          end
        end
      end

      lines << ""
    end

    lines.join("\n")
  end
end
