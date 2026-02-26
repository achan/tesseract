class FeedsController < ApplicationController
  ITEMS_PER_PAGE = 50

  before_action :set_feed, only: [:update, :destroy, :events, :move]

  def create
    max_position = Feed.maximum(:position) || -1
    @feed = Feed.new(name: params[:name], position: max_position + 1)

    if @feed.save
      add_channel_sources(@feed, Array(params[:source_ids]).map(&:to_i))
      update_workspace_sources(@feed, params[:auto_include_workspace_ids], params[:include_dms_workspace_ids])
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
      source_ids = Array(params[:source_ids]).map(&:to_i)
      dm_channel_ids = SlackChannel.where("channel_id LIKE 'D%'").select(:id)
      @feed.feed_sources.where(source_type: "SlackChannel")
        .where.not(source_id: source_ids)
        .where.not(source_id: dm_channel_ids)
        .destroy_all
      existing_ids = @feed.feed_sources.where(source_type: "SlackChannel").pluck(:source_id)
      (source_ids - existing_ids).each do |channel_id|
        @feed.feed_sources.create!(source_type: "SlackChannel", source_id: channel_id)
      end
    end
    if params.key?(:auto_include_workspace_ids) || params.key?(:include_dms_workspace_ids)
      update_workspace_sources(@feed, params[:auto_include_workspace_ids], params[:include_dms_workspace_ids])
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

  def add_channel_sources(feed, source_ids)
    existing_ids = feed.feed_sources.where(source_type: "SlackChannel").pluck(:source_id)
    (source_ids - existing_ids).each do |channel_id|
      feed.feed_sources.create!(source_type: "SlackChannel", source_id: channel_id)
    end
  end

  def update_workspace_sources(feed, auto_include_workspace_ids, include_dms_workspace_ids)
    auto_include_ids = Array(auto_include_workspace_ids).map(&:to_i)
    include_dms_ids = Array(include_dms_workspace_ids).map(&:to_i)
    all_workspace_ids = auto_include_ids | include_dms_ids

    feed.feed_sources.where(source_type: "Workspace").where.not(source_id: all_workspace_ids).destroy_all

    all_workspace_ids.each do |wid|
      opts = {
        "auto_include_new_channels" => auto_include_ids.include?(wid),
        "include_dms" => include_dms_ids.include?(wid)
      }
      fs = feed.feed_sources.find_or_initialize_by(source_type: "Workspace", source_id: wid)
      was_include_dms = fs.persisted? && fs.include_dms?
      fs.options = opts
      fs.save!

      if opts["include_dms"] && !was_include_dms
        SlackChannel.where(workspace_id: wid).where("channel_id LIKE 'D%'").find_each do |ch|
          feed.feed_sources.create_or_find_by!(source: ch)
        end
      elsif !opts["include_dms"] && was_include_dms
        dm_channel_ids = SlackChannel.where(workspace_id: wid).where("channel_id LIKE 'D%'").select(:id)
        feed.feed_sources.where(source_type: "SlackChannel", source_id: dm_channel_ids).destroy_all
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
