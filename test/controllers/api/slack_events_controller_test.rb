require "test_helper"

class Api::SlackEventsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @signing_secret = "test_signing_secret"
    ENV["SLACK_SIGNING_SECRET"] = @signing_secret
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
      team_id: "T_TEST_ONE",
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
      team_id: "T_TEST_ONE",
      event_id: "Ev_NEW_002",
      event: { type: "message", channel: "C_GENERAL", user: "U1", ts: "1.2", text: "hello" }
    }

    body = payload.to_json
    timestamp = Time.now.to_i.to_s
    sig_basestring = "v0:#{timestamp}:#{body}"
    signature = "v0=#{OpenSSL::HMAC.hexdigest("SHA256", @signing_secret, sig_basestring)}"

    assert_difference "SlackEvent.count", 1 do
      post api_slack_events_path, params: body,
        headers: {
          "CONTENT_TYPE" => "application/json",
          "X-Slack-Request-Timestamp" => timestamp,
          "X-Slack-Signature" => signature
        }
    end

    assert_response :success
  end

  test "deduplicates events" do
    payload = {
      type: "event_callback",
      team_id: "T_TEST_ONE",
      event_id: "Ev_MSG_001",
      event: { type: "message", channel: "C_GENERAL", user: "U1", ts: "1.1", text: "dup" }
    }

    body = payload.to_json
    timestamp = Time.now.to_i.to_s
    sig_basestring = "v0:#{timestamp}:#{body}"
    signature = "v0=#{OpenSSL::HMAC.hexdigest("SHA256", @signing_secret, sig_basestring)}"

    assert_no_difference "SlackEvent.count" do
      post api_slack_events_path, params: body,
        headers: {
          "CONTENT_TYPE" => "application/json",
          "X-Slack-Request-Timestamp" => timestamp,
          "X-Slack-Signature" => signature
        }
    end

    assert_response :success
  end

  test "ignores events for inactive channels" do
    payload = {
      type: "event_callback",
      team_id: "T_TEST_ONE",
      event_id: "Ev_RANDOM_001",
      event: { type: "message", channel: "C_RANDOM", user: "U1", ts: "1.1", text: "ignored" }
    }

    body = payload.to_json
    timestamp = Time.now.to_i.to_s
    sig_basestring = "v0:#{timestamp}:#{body}"
    signature = "v0=#{OpenSSL::HMAC.hexdigest("SHA256", @signing_secret, sig_basestring)}"

    assert_no_difference "SlackEvent.count" do
      post api_slack_events_path, params: body,
        headers: {
          "CONTENT_TYPE" => "application/json",
          "X-Slack-Request-Timestamp" => timestamp,
          "X-Slack-Signature" => signature
        }
    end

    assert_response :success
  end
end
