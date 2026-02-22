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
    user_names = resolve_user_names(events)

    prompt = build_prompt(grouped_by_channel, user_names)

    update_live_activity(subtitle: "Calling Claude...")

    result_text = call_claude(prompt)
    parsed = extract_json(result_text)

    Overview.create!(
      summary: parsed["summary"].presence,
      body: parsed["details"] || result_text,
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

  def resolve_user_names(events)
    workspace = Workspace.first
    return {} unless workspace

    user_ids = events.map(&:user_id).compact.uniq
    user_ids.each_with_object({}) do |uid, map|
      map[uid] = workspace.resolve_user_name(uid)
    end
  end

  def resolve_slack_text(text, user_names:)
    return "" if text.blank?

    text
      .gsub(/<@(U[A-Z0-9]+)>/) { |_| "@#{user_names[$1] || $1}" }
      .gsub(/<#C[A-Z0-9]+\|([^>]+)>/) { |_| "##{$1}" }
      .gsub(/<(https?:\/\/[^|>]+)\|([^>]+)>/) { |_| $2 }
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

  def build_prompt(grouped_by_channel, user_names)
    lines = []
    lines << "Analyze the following Slack activity from the last hour and produce a structured overview."
    lines << ""
    lines << 'Return ONLY valid JSON (no markdown fences):'
    lines << '{ "summary": "...", "details": "..." }'
    lines << ""
    lines << "SUMMARY (the \"summary\" field):"
    lines << "- 2-3 sentences capturing the most significant activity and anything notable"
    lines << "- Should stand alone as a useful overview without the details"
    lines << "- Plain text, no markdown"
    lines << ""
    lines << "DETAILS (the \"details\" field):"
    lines << "- Mostly bullet points of things I should know"
    lines << "- Group by theme, not by channel"
    lines << "- Use **bold** headers (not ## markdown headers) for 3-5 theme sections"
    lines << "- Higher-priority channels deserve more attention"
    lines << "- Name people when relevant"
    lines << "- For exam/provider quality: focus on patterns, not per-exam scores; only call out notably strong or weak providers"
    lines << "- Surface notable events (outages, errors, no-shows, business developments) but don't frame as action items"
    lines << "- Omit routine/low-signal messages (greetings, acknowledgments, clock-in/out)"
    lines << ""

    # Channel context
    channels = grouped_by_channel.keys.sort_by(&:priority)
    lines << "## Channel Context"
    lines << "Each channel has a priority (1=most important, 5=least) and a description of what"
    lines << "typically happens there. Use this to weight your analysis — give more attention and"
    lines << "detail to higher-priority channels, and treat their activity as more noteworthy."
    lines << ""
    channels.each do |channel|
      desc = channel.interaction_description.present? ? ": #{channel.interaction_description}" : ""
      lines << "- ##{channel.display_name} (Priority #{channel.priority})#{desc}"
    end
    lines << ""

    # Messages
    lines << "## Messages"
    lines << ""

    grouped_by_channel.each do |channel, channel_events|
      lines << "### ##{channel.display_name}"
      lines << ""

      grouped = group_by_thread(channel_events)

      grouped[:top_level].each do |event|
        text = event.payload.is_a?(Hash) ? event.payload["text"] : ""
        text = resolve_slack_text(text, user_names: user_names)
        author = user_names[event.user_id] || event.user_id
        lines << "[#{event.ts}] #{author}: #{text}"

        thread_replies = grouped[:threads][event.ts]
        if thread_replies
          thread_replies.each do |reply|
            reply_text = reply.payload.is_a?(Hash) ? reply.payload["text"] : ""
            reply_text = resolve_slack_text(reply_text, user_names: user_names)
            reply_author = user_names[reply.user_id] || reply.user_id
            lines << "  [#{reply.ts}] #{reply_author}: #{reply_text}"
          end
        end
      end

      lines << ""
    end

    lines << "Remember: respond with ONLY a JSON object, no other text."

    lines.join("\n")
  end

  def extract_json(text)
    text = text.sub(/\A\s*```\w*\n/, "").sub(/\n```\s*\z/, "")

    begin
      return JSON.parse(text)
    rescue JSON::ParserError
    end

    if (match = text.match(/\{.*\}/m))
      begin
        return JSON.parse(match[0])
      rescue JSON::ParserError
      end
    end

    { "summary" => nil, "details" => text }
  end
end
