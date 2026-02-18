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

  test "active scope returns only active channels" do
    workspace = workspaces(:one)
    active = workspace.slack_channels.active
    assert active.all?(&:active?)
    assert_equal 1, active.count
  end
end
