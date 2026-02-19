require "test_helper"

class Api::SlackEventsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @signing_secret = workspaces(:one).signing_secret
  end

  test "url_verification returns challenge" do
    payload = { type: "url_verification", challenge: "abc123" }
    post api_slack_events_path, params: payload.to_json,
      headers: { "CONTENT_TYPE" => "application/json" }

    assert_response :success
    assert_equal "abc123", JSON.parse(response.body)["challenge"]
  end

  test "rejects requests with invalid signature" do
    payload = {
      type: "event_callback",
      event_id: "Ev_NEW_001",
      event: { type: "message", channel: "C_GENERAL", user: "U1", ts: "1.1", text: "hi" }
    }

    post api_slack_events_path, params: payload.to_json,
      headers: {
        "CONTENT_TYPE" => "application/json",
        "X-Slack-Request-Timestamp" => Time.now.to_i.to_s,
        "X-Slack-Signature" => "v0=invalid"
      }

    assert_response :unauthorized
  end

  test "stores event with valid signature" do
    payload = {
      type: "event_callback",
      event_id: "Ev_NEW_002",
      event: { type: "message", channel: "C_GENERAL", user: "U1", ts: "1.2", text: "hello" }
    }

    assert_difference "SlackEvent.count", 1 do
      post_signed payload
    end

    assert_response :success
  end

  test "deduplicates events" do
    payload = {
      type: "event_callback",
      event_id: "Ev_MSG_001",
      event: { type: "message", channel: "C_GENERAL", user: "U1", ts: "1.1", text: "dup" }
    }

    assert_no_difference "SlackEvent.count" do
      post_signed payload
    end

    assert_response :success
  end

  test "auto-creates channel for unknown channel_id" do
    payload = {
      type: "event_callback",
      event_id: "Ev_UNKNOWN_001",
      event: { type: "message", channel: "C_NEWCHAN", user: "U1", ts: "1.1", text: "hello" }
    }

    assert_difference ["SlackEvent.count", "SlackChannel.count"], 1 do
      post_signed payload
    end

    assert_response :success
    channel = SlackChannel.find_by(channel_id: "C_NEWCHAN")
    assert channel
    assert_equal workspaces(:one), channel.workspace
  end

  test "reuses existing channel for subsequent events" do
    payload1 = {
      type: "event_callback",
      event_id: "Ev_REUSE_001",
      event: { type: "message", channel: "C_REUSE", user: "U1", ts: "1.1", text: "first" }
    }

    payload2 = {
      type: "event_callback",
      event_id: "Ev_REUSE_002",
      event: { type: "message", channel: "C_REUSE", user: "U1", ts: "1.2", text: "second" }
    }

    assert_difference "SlackChannel.count", 1 do
      post_signed payload1
      post_signed payload2
    end

    assert_equal 2, SlackChannel.find_by(channel_id: "C_REUSE").slack_events.count
  end

  private

  def post_signed(payload)
    body = payload.to_json
    timestamp = Time.now.to_i.to_s
    sig_basestring = "v0:#{timestamp}:#{body}"
    signature = "v0=#{OpenSSL::HMAC.hexdigest("SHA256", @signing_secret, sig_basestring)}"

    post api_slack_events_path, params: body,
      headers: {
        "CONTENT_TYPE" => "application/json",
        "X-Slack-Request-Timestamp" => timestamp,
        "X-Slack-Signature" => signature
      }
  end
end
