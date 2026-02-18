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

  test "new renders form" do
    get new_workspace_slack_channel_path(@workspace)
    assert_response :success
  end

  test "create with valid params" do
    assert_difference "SlackChannel.count", 1 do
      post workspace_slack_channels_path(@workspace), params: {
        slack_channel: { channel_id: "C_NEW", channel_name: "new-channel" }
      }
    end
    assert_redirected_to workspace_slack_channel_path(@workspace, SlackChannel.last)
  end

  test "create with invalid params renders new" do
    assert_no_difference "SlackChannel.count" do
      post workspace_slack_channels_path(@workspace), params: {
        slack_channel: { channel_id: "" }
      }
    end
    assert_response :unprocessable_entity
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
end
