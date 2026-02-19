names   = ENV.fetch("SLACK_WORKSPACES", "").split(",")
tokens  = ENV.fetch("SLACK_USER_OAUTH_TOKENS", "").split(",")
secrets = ENV.fetch("SLACK_SIGNING_SECRETS", "").split(",")

names.each_with_index do |name, i|
  workspace = Workspace.find_or_initialize_by(team_name: name.strip)
  workspace.user_token     = tokens[i]&.strip if tokens[i].present?
  workspace.signing_secret = secrets[i]&.strip if secrets[i].present?
  workspace.include_dms   = true
  workspace.include_mpims = true
  workspace.save!

  env_key = "SLACK_CHANNELS_#{name.strip.upcase.gsub(/\s+/, "_")}"
  channel_ids = ENV.fetch(env_key, "").split(",").map(&:strip).reject(&:empty?)

  channel_ids.each do |channel_id|
    channel = workspace.slack_channels.find_or_create_by!(channel_id: channel_id)
    channel.save! if channel.channel_name.blank?
  end

  puts "  #{workspace.team_name}: #{channel_ids.size} channel(s)"
end

puts "Seeded #{names.size} workspace(s)"

# -- Fake events for development --
workspace = Workspace.first_or_create!(team_name: "Fake Workspace")
channel = workspace.slack_channels.first_or_create!(
  channel_id: "C0FAKE001",
  channel_name: "general"
)

users = %w[U_ALICE U_BOB U_CAROL U_DAVE U_EVE]

messages = [
  ":wrench: Hey team, just pushed the fix for the **login bug**. See `app/controllers/sessions_controller.rb` for details.",
  ":eyes: Can someone review my PR? It's a *small* change to the `User` model — just adds validation.",
  ":rocket: Heads up: deploying to **staging** in 10 minutes. Changes include:\n- Updated `Gemfile`\n- New migration for `orders` table",
  ":rotating_light: The API latency issue is back. Getting `504 Gateway Timeout` on `/api/v2/search`. Looking into it now.",
  ":mega: Standup reminder: please post your updates by noon.\n\n**Format:**\n1. What you did yesterday\n2. What you're doing today\n3. Any blockers",
  ":mag: Found the root cause — it was a missing index on `orders.customer_id`. Fix:\n```sql\nADD INDEX idx_orders_customer_id ON orders (customer_id);\n```",
  ":art: New design mockups are in Figma. Key changes:\n- **Sidebar** navigation redesign\n- Updated *color palette* for dark mode\n- New `Button` component variants",
  ":white_check_mark: CI is green, merging to `main`. All **347 tests** passing.",
  ":lock: Does anyone have access to the **production** logs? Need to check `ActionController::RoutingError` from last night.",
  ":memo: Retro notes are in the shared doc. Please add your items under:\n- **Went well**\n- **Could improve**\n- **Action items**",
  ":wave: Just onboarded the new intern — she starts Monday. She'll be working on the `slack-bot` repo with the **integrations** team.",
  ":warning: Reminder: we're freezing deploys **Friday at 5pm** for the release. Make sure your PRs are merged before then!",
  ":gem: Upgraded Rails to `8.0.2`. Key changes:\n1. Fixed `ActiveRecord::ConnectionPool` leak\n2. New `normalizes` API\n3. **Solid Queue** improvements",
  ":tada: The search feature is live! Uses `pg_trgm` for fuzzy matching. If you see issues, check the `SearchController#index` action.",
  ":fire: Slack bot is throwing `429 Too Many Requests`. Need to add rate limiting with something like:\n```ruby\nSlack::Web::Client.new(token: token).tap do |client|\n  client.config.retry_after = true\nend\n```",
  ":chart_with_upwards_trend: Database migration ran successfully in **staging**. Table `slack_events` now has ~*2.3M* rows. Query performance looks good with the new index.",
  ":phone: Who's on-call this weekend? Current rotation:\n- **Primary:** @alice\n- **Secondary:** @bob\n- Escalation: `#incidents` channel",
  ":bug: Customer reported a bug with file uploads. Error: `ActiveStorage::IntegrityError`. Looks like the **checksum** validation is failing on large files (>100MB).",
  ":calendar: Sprint planning moved to **Thursday** this week. Agenda:\n1. Review `v2.4` milestone\n2. Estimate *new* backlog items\n3. Assign `P0` bugs",
  ":raised_hands: Great work on the launch everyone! Some **highlights:**\n- Zero downtime deployment\n- `99.97%` uptime during rollout\n- *3x* improvement in response times"
]

base_time = 2.hours.ago

messages.each_with_index do |text, i|
  ts = (base_time + (i * 5).minutes).to_f.to_s
  channel.slack_events.create!(
    event_id: "fake_#{SecureRandom.hex(8)}",
    event_type: "message",
    user_id: users.sample,
    ts: ts,
    payload: { "text" => text },
    created_at: base_time + (i * 5).minutes
  )
end

puts "Seeded 20 fake events in ##{channel.channel_name}"
