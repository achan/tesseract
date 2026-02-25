class DashboardController < ApplicationController
  ITEMS_PER_PAGE = 50

  def index
    @live_activities = LiveActivity.visible

    @action_items = ActionItem
      .active
      .where(status: ActionItem::DASHBOARD_STATUSES)
      .where(
        "(source_type = 'SlackChannel' AND source_id IN (?)) OR (source_type = 'Profile' AND source_id IN (?))",
        active_slack_channel_ids, active_profile_ids
      )
      .order(
        Arel.sql("CASE status WHEN 'untriaged' THEN 0 WHEN 'in_progress' THEN 1 WHEN 'todo' THEN 2 END"),
        priority: :asc,
        created_at: :asc
      )

    @overview = pick_overview

    ensure_default_feed
    @feeds = Feed.ordered
    @feed_items = {}
    @feed_has_more = {}
    @feeds.each do |feed|
      scope = feed_items_scope(feed)
      @feed_items[feed.id] = scope.limit(ITEMS_PER_PAGE)
      @feed_has_more[feed.id] = scope.limit(ITEMS_PER_PAGE + 1).count > ITEMS_PER_PAGE
    end

    @available_channels = available_channels
  end

  def events
    scope = events_scope
    scope = scope.where("slack_events.created_at < ?", Time.parse(params[:before])) if params[:before].present?
    @events = scope.limit(ITEMS_PER_PAGE)
    @has_more = scope.limit(ITEMS_PER_PAGE + 1).count > ITEMS_PER_PAGE
  end

  private

  def ensure_default_feed
    return if Feed.exists?

    feed = Feed.create!(name: "All Messages", position: 0)
    SlackChannel.visible.channels.current.where(workspace_id: active_workspace_ids).find_each do |channel|
      feed.feed_sources.create!(source: channel)
    end

    SlackEvent.messages
      .where(slack_channel_id: feed.feed_sources.where(source_type: "SlackChannel").pluck(:source_id))
      .find_each do |event|
        feed.feed_items.create!(source: event, occurred_at: event.created_at)
      end
  end

  def pick_overview
    enabled_profiles = Profile.where(enabled: true)
    scope = if enabled_profiles.count == 1
      Overview.where(profile_id: enabled_profiles.first.id)
    else
      Overview.where(profile_id: nil)
    end
    scope.order(created_at: :desc).first
  end

  def feed_items_scope(feed)
    feed.feed_items.ordered
      .joins("INNER JOIN slack_events ON feed_items.source_id = slack_events.id AND feed_items.source_type = 'SlackEvent'")
      .joins("INNER JOIN slack_channels ON slack_events.slack_channel_id = slack_channels.id")
      .where(slack_channels: { workspace_id: active_workspace_ids })
      .includes(source: { slack_channel: :workspace })
  end

  def events_scope
    SlackEvent
      .messages
      .joins(:slack_channel).where(slack_channels: { hidden: false, workspace_id: active_workspace_ids })
      .includes(slack_channel: :workspace)
      .order(created_at: :desc)
  end

  def available_channels
    SlackChannel.visible.channels.current
      .where(workspace_id: active_workspace_ids)
      .includes(:workspace)
      .order(:channel_name)
  end
end
