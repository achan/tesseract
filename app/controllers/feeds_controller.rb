class FeedsController < ApplicationController
  ITEMS_PER_PAGE = 50

  before_action :set_feed, only: [:update, :destroy, :events, :move]

  def create
    max_position = Feed.maximum(:position) || -1
    @feed = Feed.new(name: params[:name], position: max_position + 1)

    if @feed.save
      sync_sources(@feed, params[:source_ids])
      backfill_feed_items(@feed)
      load_feed_items(@feed)
      @available_channels = available_channels
      respond_to do |format|
        format.turbo_stream
      end
    else
      head :unprocessable_entity
    end
  end

  def update
    @feed.update!(name: params[:name]) if params[:name].present?
    if params[:source_ids]
      sync_sources(@feed, params[:source_ids])
      backfill_feed_items(@feed)
    end
    load_feed_items(@feed)
    @available_channels = available_channels

    respond_to do |format|
      format.turbo_stream
    end
  end

  def destroy
    @feed.destroy!
    respond_to do |format|
      format.turbo_stream { render turbo_stream: turbo_stream.remove("feed_column_#{@feed.id}") }
    end
  end

  def events
    scope = feed_items_scope(@feed)
    scope = scope.where("feed_items.occurred_at < ?", Time.parse(params[:before])) if params[:before].present?
    @feed_items = scope.limit(ITEMS_PER_PAGE)
    @has_more = scope.limit(ITEMS_PER_PAGE + 1).count > ITEMS_PER_PAGE
  end

  def move
    @feed.update!(position: params[:position].to_i)
    head :ok
  end

  private

  def set_feed
    @feed = Feed.find(params[:id])
  end

  def sync_sources(feed, source_ids)
    source_ids = Array(source_ids).map(&:to_i)
    feed.feed_sources.where.not(source_id: source_ids, source_type: "SlackChannel").destroy_all
    existing_ids = feed.feed_sources.where(source_type: "SlackChannel").pluck(:source_id)
    (source_ids - existing_ids).each do |channel_id|
      feed.feed_sources.create!(source_type: "SlackChannel", source_id: channel_id)
    end
  end

  def backfill_feed_items(feed)
    channel_ids = feed.feed_sources.where(source_type: "SlackChannel").pluck(:source_id)
    # Remove feed items for channels no longer in the feed
    feed.feed_items
      .joins("INNER JOIN slack_events ON feed_items.source_id = slack_events.id AND feed_items.source_type = 'SlackEvent'")
      .where.not(slack_events: { slack_channel_id: channel_ids })
      .delete_all

    # Add feed items for new channels
    SlackEvent.messages.where(slack_channel_id: channel_ids).find_each do |event|
      feed.feed_items.create_or_find_by!(source: event) do |fi|
        fi.occurred_at = event.created_at
      end
    end
  end

  def load_feed_items(feed)
    scope = feed_items_scope(feed)
    @feed_items = scope.limit(ITEMS_PER_PAGE)
    @feed_has_more = scope.limit(ITEMS_PER_PAGE + 1).count > ITEMS_PER_PAGE
  end

  def feed_items_scope(feed)
    feed.feed_items.ordered
      .joins("INNER JOIN slack_events ON feed_items.source_id = slack_events.id AND feed_items.source_type = 'SlackEvent'")
      .joins("INNER JOIN slack_channels ON slack_events.slack_channel_id = slack_channels.id")
      .where(slack_channels: { workspace_id: active_workspace_ids })
      .includes(source: { slack_channel: :workspace })
  end

  def available_channels
    SlackChannel.visible.channels.current
      .where(workspace_id: active_workspace_ids)
      .includes(:workspace)
      .order(:channel_name)
  end
end
