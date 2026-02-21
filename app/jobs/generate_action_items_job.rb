class GenerateActionItemsJob < ApplicationJob
  queue_as :default

  def perform(slack_event_id:)
    event = SlackEvent.find_by(id: slack_event_id)
    return unless event

    channel = event.slack_channel

    latest_event_id = channel.slack_events.order(created_at: :desc).pick(:id)
    return unless latest_event_id == event.id

    events = channel.slack_events
      .where("created_at > ?", 2.hours.ago)
      .order(:created_at)

    return if events.empty?

    start_live_activity(
      activity_type: "action_items",
      activity_id: slack_event_id.to_s,
      title: "Extracting action items",
      subtitle: "##{channel.channel_name}"
    )

    grouped = group_by_thread(events)
    prompt = build_prompt(grouped, channel)

    update_live_activity(subtitle: "##{channel.channel_name} — Calling Claude...")

    result_text = call_claude(prompt)
    parsed = extract_json(result_text)

    items = parsed["action_items"] || []
    items.each do |item|
      channel.action_items.create!(
        description: item["description"],
        assignee_user_id: item["assignee"],
        source_ts: item["source_ts"],
        priority: item["priority"] || 3,
        status: "untriaged"
      )
    end

    stop_live_activity(subtitle: "##{channel.channel_name}", metadata: { "items" => items.size })
  rescue => e
    stop_live_activity(subtitle: "##{channel.channel_name} — Failed")
    raise
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

  def build_prompt(grouped, channel)
    existing_items = channel.all_action_items.order(:created_at)

    lines = ["Extract NEW action items from the following Slack channel activity."]
    lines << ""
    lines << "Pay special attention to important dates mentioned in messages (deadlines, meetings,"
    lines << "launches, reviews, etc.) and create action items for them."
    lines << ""
    lines << "For each action item, assess its priority (1-5) based on the message content:"
    lines << "- 1: Urgent/blocking — outages, broken builds, security issues, explicit urgency"
    lines << "- 2: High — time-sensitive requests, approaching deadlines, important decisions needed"
    lines << "- 3: Normal — standard tasks, follow-ups, general requests"
    lines << "- 4: Low — nice-to-haves, minor improvements, non-urgent questions"
    lines << "- 5: Minimal — informational, no real action needed soon"
    lines << "DMs and group DMs are direct conversations — treat their action items as higher priority"
    lines << "than equivalent items from public channels."
    lines << "Use the channel priority as a baseline but adjust per-item based on content and tone."
    lines << ""
    lines << "Return ONLY valid JSON (no markdown fences) with this structure:"
    lines << '{ "action_items": [{ "description": "...", "assignee": "user_id or null", "source_ts": "...", "priority": 1-5 }] }'
    lines << "You may return zero, one, or multiple action items — include as many as are warranted by the messages."
    lines << "If there are no action items, return: { \"action_items\": [] }"
    lines << ""

    if existing_items.any?
      lines << "## Existing Action Items"
      lines << "The following action items already exist for this channel. Do NOT duplicate these."
      lines << "Only create action items for genuinely new tasks from the messages below."
      lines << ""
      existing_items.each do |item|
        assignee = item.assignee_user_id.present? ? " (assigned to #{item.assignee_user_id})" : ""
        lines << "- [#{item.status}] [P#{item.priority}] #{item.description}#{assignee}"
      end
      lines << ""
    end

    lines << "## Channel Context"
    lines << "Priority: #{channel.priority} (1=highest, 5=lowest)"
    lines << "Interaction description: #{channel.interaction_description}" if channel.interaction_description.present?
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

    lines << ""
    lines << "Remember: respond with ONLY a JSON object, no other text."

    lines.join("\n")
  end

  def extract_json(text)
    # Strip markdown code fences
    text = text.sub(/\A\s*```\w*\n/, "").sub(/\n```\s*\z/, "")

    # Try parsing as-is first
    begin
      return JSON.parse(text)
    rescue JSON::ParserError
      # Fall through to extraction
    end

    # Try to extract a JSON object from surrounding text
    if (match = text.match(/\{.*\}/m))
      begin
        return JSON.parse(match[0])
      rescue JSON::ParserError
        # Fall through
      end
    end

    # Give up — let the job fail
    JSON.parse(text)
  end
end
