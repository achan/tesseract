class SummarizeJob < ApplicationJob
  queue_as :default

  def perform(workspace_id:, channel_id:, period_start: 24.hours.ago, period_end: Time.current)
    workspace = Workspace.find(workspace_id)
    channel = workspace.slack_channels.find_by!(channel_id: channel_id)
    events = channel.slack_events
      .in_window(period_start, period_end)
      .order(:created_at)

    return if events.empty?

    grouped = group_by_thread(events)
    prompt = build_prompt(grouped)

    result_text = call_claude(prompt)
    parsed = JSON.parse(result_text)

    summary = Summary.create!(
      source: channel,
      period_start: period_start,
      period_end: period_end,
      summary_text: parsed["summary"],
      model_used: "claude-cli"
    )

    (parsed["action_items"] || []).each do |item|
      summary.action_items.create!(
        source: channel,
        description: item["description"],
        assignee_user_id: item["assignee"],
        source_ts: item["source_ts"],
        status: "open"
      )
    end
  end

  private

  def call_claude(prompt)
    output, status = Open3.capture2(
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

  def build_prompt(grouped)
    lines = [ "Summarize the following Slack channel activity and extract action items." ]
    lines << ""
    lines << "Return ONLY valid JSON (no markdown fences) with this structure:"
    lines << '{ "summary": "...", "action_items": [{ "description": "...", "assignee": "user_id or null", "source_ts": "..." }] }'
    lines << ""
    lines << "## Messages"
    lines << ""

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

    lines.join("\n")
  end
end
