module Api
  class DeploysController < ApplicationController
    skip_before_action :verify_authenticity_token
    skip_before_action :authenticate

    def create
      return head :unauthorized unless valid_signature?

      payload = JSON.parse(request_body)
      return head :ok unless payload["ref"] == "refs/heads/main"

      commit_sha = payload["after"]

      LiveActivity.find_or_initialize_by(
        activity_type: "deploy",
        activity_id: commit_sha
      ).update!(
        title: "Deploying",
        subtitle: commit_sha[0, 7],
        status: "active",
        metadata: {},
        ends_at: nil
      )

      deploy_log = Rails.root.join("log/deploy.log")
      pid = Process.spawn("bin/deploy", commit_sha, chdir: Rails.root.to_s, out: deploy_log.to_s, err: deploy_log.to_s)
      Process.detach(pid)

      head :accepted
    end

    private

    def valid_signature?
      secret = ENV["GITHUB_WEBHOOK_SECRET"]
      return false if secret.blank?

      signature = request.headers["X-Hub-Signature-256"]
      return false if signature.blank?

      computed = "sha256=#{OpenSSL::HMAC.hexdigest("SHA256", secret, request_body)}"
      ActiveSupport::SecurityUtils.secure_compare(computed, signature)
    end

    def request_body
      @_raw_body ||= begin
        request.body.rewind
        body = request.body.read
        request.body.rewind
        body
      end
    end
  end
end
