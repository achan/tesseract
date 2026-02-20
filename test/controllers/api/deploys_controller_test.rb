require "test_helper"

class Api::DeploysControllerTest < ActionDispatch::IntegrationTest
  SECRET = "test_webhook_secret"

  test "rejects missing signature" do
    with_secret do
      post api_deploy_path, params: push_payload.to_json,
        headers: { "CONTENT_TYPE" => "application/json" }

      assert_response :unauthorized
    end
  end

  test "rejects invalid signature" do
    with_secret do
      post api_deploy_path, params: push_payload.to_json,
        headers: {
          "CONTENT_TYPE" => "application/json",
          "X-Hub-Signature-256" => "sha256=invalid"
        }

      assert_response :unauthorized
    end
  end

  test "rejects when secret not configured" do
    ENV.delete("GITHUB_WEBHOOK_SECRET")

    post api_deploy_path, params: push_payload.to_json,
      headers: {
        "CONTENT_TYPE" => "application/json",
        "X-Hub-Signature-256" => "sha256=anything"
      }

    assert_response :unauthorized
  end

  test "ignores non-main branch pushes" do
    with_secret do
      payload = push_payload(ref: "refs/heads/feature-branch")
      post_signed(payload)

      assert_response :ok
    end
  end

  test "spawns deploy for valid main push" do
    with_secret do
      spawn_args = nil
      original_spawn = Process.method(:spawn)
      original_detach = Process.method(:detach)

      Process.define_singleton_method(:spawn) { |*args, **opts| spawn_args = [args, opts]; 1 }
      Process.define_singleton_method(:detach) { |_pid| }

      post_signed(push_payload)

      Process.define_singleton_method(:spawn, original_spawn)
      Process.define_singleton_method(:detach, original_detach)

      assert_response :accepted
      assert_not_nil spawn_args, "Expected Process.spawn to be called"
      assert_equal "bin/deploy", spawn_args[0][0]
    end
  end

  private

  def push_payload(ref: "refs/heads/main")
    { ref: ref, after: "abc123" }
  end

  def post_signed(payload)
    body = payload.to_json
    signature = "sha256=#{OpenSSL::HMAC.hexdigest("SHA256", SECRET, body)}"

    post api_deploy_path, params: body,
      headers: {
        "CONTENT_TYPE" => "application/json",
        "X-Hub-Signature-256" => signature
      }
  end

  def with_secret(&block)
    original = ENV["GITHUB_WEBHOOK_SECRET"]
    ENV["GITHUB_WEBHOOK_SECRET"] = SECRET
    yield
  ensure
    if original
      ENV["GITHUB_WEBHOOK_SECRET"] = original
    else
      ENV.delete("GITHUB_WEBHOOK_SECRET")
    end
  end
end
