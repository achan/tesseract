require "test_helper"

class SlackChannelsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @workspace = workspaces(:one)
    @channel = slack_channels(:general)
  end

  test "show renders channel detail" do
    get workspace_slack_channel_path(@workspace, @channel)
    assert_response :success
  end

  test "edit renders form" do
    get edit_workspace_slack_channel_path(@workspace, @channel)
    assert_response :success
  end

  test "update with valid params" do
    patch workspace_slack_channel_path(@workspace, @channel), params: {
      slack_channel: { channel_name: "updated-general" }
    }
    assert_redirected_to workspace_slack_channel_path(@workspace, @channel)
    assert_equal "updated-general", @channel.reload.channel_name
  end

  test "destroy deletes channel" do
    assert_difference "SlackChannel.count", -1 do
      delete workspace_slack_channel_path(@workspace, @channel)
    end
    assert_redirected_to root_path
  end

  test "toggle_hidden toggles the hidden flag" do
    assert_not @channel.hidden?
    patch toggle_hidden_workspace_slack_channel_path(@workspace, @channel)
    assert_redirected_to settings_path
    assert @channel.reload.hidden?

    patch toggle_hidden_workspace_slack_channel_path(@workspace, @channel)
    assert_not @channel.reload.hidden?
  end
end
