require "test_helper"

class SlackChannelTest < ActiveSupport::TestCase
  test "validates channel_id presence" do
    channel = SlackChannel.new(workspace: workspaces(:one))
    assert_not channel.valid?
    assert_includes channel.errors[:channel_id], "can't be blank"
  end

  test "validates uniqueness scoped to workspace" do
    channel = SlackChannel.new(
      workspace: workspaces(:one),
      channel_id: slack_channels(:general).channel_id,
      channel_name: "dup"
    )
    assert_not channel.valid?
    assert_includes channel.errors[:channel_id], "has already been taken"
  end

  test "visible scope returns only non-hidden channels" do
    workspace = workspaces(:one)
    visible = workspace.slack_channels.visible
    assert visible.none?(&:hidden?)
    assert_equal 1, visible.count
  end

  test "current scope excludes channels that have a successor" do
    workspace = workspaces(:one)
    current = workspace.slack_channels.current
    assert_includes current, slack_channels(:general)
    assert_includes current, slack_channels(:random)
    assert_not_includes current, slack_channels(:archived_general)
  end

  # --- link_predecessor ---

  test "link_predecessor links matching channel and copies settings" do
    general = slack_channels(:general)

    new_channel = SlackChannel.create!(
      workspace: workspaces(:one),
      channel_id: "C_GENERAL_NEW",
      channel_name: "general"
    )

    assert_equal general.id, new_channel.predecessor_id
    assert_equal false, new_channel.hidden
    assert_equal true, new_channel.actionable
    assert_equal general.priority, new_channel.priority
    assert_equal general.interaction_description, new_channel.interaction_description
  end

  test "link_predecessor skips DMs" do
    channel = SlackChannel.create!(
      workspace: workspaces(:one),
      channel_id: "D_DM_001",
      channel_name: "DM: Someone"
    )

    assert_nil channel.predecessor_id
  end

  test "link_predecessor skips MPIMs" do
    channel = SlackChannel.create!(
      workspace: workspaces(:one),
      channel_id: "G_MPIM_001",
      channel_name: "mpdm-group"
    )

    assert_nil channel.predecessor_id
  end

  test "link_predecessor skips unresolved names" do
    channel = SlackChannel.create!(
      workspace: workspaces(:one),
      channel_id: "C_UNRESOLVED"
    )

    assert_nil channel.predecessor_id
  end

  test "link_predecessor skips channels in different workspaces" do
    channel = SlackChannel.create!(
      workspace: workspaces(:two),
      channel_id: "C_GENERAL_WS2",
      channel_name: "general"
    )

    assert_nil channel.predecessor_id
  end

  test "link_predecessor skips channels that already have a successor" do
    general = slack_channels(:general)
    archived = slack_channels(:archived_general)

    # general already has archived_general as predecessor (from fixtures)
    # So archived_general already has a successor

    # New channel should link to general (which has no successor yet)
    first = SlackChannel.create!(
      workspace: workspaces(:one),
      channel_id: "C_GENERAL_V2",
      channel_name: "general"
    )
    assert_equal general.id, first.predecessor_id

    # Now general has a successor (first), so the next channel should link to first
    second = SlackChannel.create!(
      workspace: workspaces(:one),
      channel_id: "C_GENERAL_V3",
      channel_name: "general"
    )
    assert_equal first.id, second.predecessor_id
  end

  # --- channel_chain / channel_chain_ids ---

  test "channel_chain returns self when no predecessor" do
    channel = slack_channels(:random)
    assert_equal [channel], channel.channel_chain
  end

  test "channel_chain traverses predecessor links" do
    general = slack_channels(:general)
    archived = slack_channels(:archived_general)

    assert_equal [general, archived], general.channel_chain
    assert_equal [general.id, archived.id], general.channel_chain_ids
  end

  test "channel_chain traverses multi-level predecessor links" do
    general = slack_channels(:general)
    archived = slack_channels(:archived_general)

    new_channel = SlackChannel.create!(
      workspace: workspaces(:one),
      channel_id: "C_GENERAL_V2",
      channel_name: "general"
    )

    assert_equal [new_channel, general, archived], new_channel.channel_chain
  end

  # --- Aggregated queries ---

  test "all_slack_events includes events from predecessor chain" do
    general = slack_channels(:general)
    archived = slack_channels(:archived_general)

    events = general.all_slack_events
    assert_includes events, slack_events(:message_one)
    assert_includes events, slack_events(:archived_event)
  end

  test "all_summaries includes summaries from predecessor chain" do
    general = slack_channels(:general)

    summaries = general.all_summaries
    assert_includes summaries, summaries(:recent_summary)
    assert_includes summaries, summaries(:archived_summary)
  end

  test "all_action_items includes action items from predecessor chain" do
    general = slack_channels(:general)

    items = general.all_action_items
    assert_includes items, action_items(:open_item)
    assert_includes items, action_items(:archived_open_item)
  end
end
