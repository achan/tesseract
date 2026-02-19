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
end
