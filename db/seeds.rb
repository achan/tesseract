names   = ENV.fetch("SLACK_WORKSPACES", "").split(",")
tokens  = ENV.fetch("SLACK_USER_OAUTH_TOKENS", "").split(",")
secrets = ENV.fetch("SLACK_SIGNING_SECRETS", "").split(",")

default_profile = Profile.find_or_create_by!(name: "Default")

names.each_with_index do |name, i|
  workspace = Workspace.find_or_initialize_by(team_name: name.strip)
  workspace.profile       ||= default_profile
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
