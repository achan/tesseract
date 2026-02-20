module Api
  class DeployController < ApplicationController
    skip_before_action :verify_authenticity_token
    skip_before_action :authenticate
    before_action :verify_signature

    def create
      payload = JSON.parse(request_body)
      ref = payload["ref"]

      branch = ENV.fetch("DEPLOY_BRANCH", "main")
      unless ref == "refs/heads/#{branch}"
        return head :ok
      end

      pid = spawn("bin/deploy --force", chdir: Rails.root.to_s, out: "log/deploy.log", err: "log/deploy.log")
      Process.detach(pid)

      head :accepted
    end

    private

    def verify_signature
      secret = ENV["GITHUB_WEBHOOK_SECRET"]
      return head :forbidden if secret.blank?

      signature = request.headers["X-Hub-Signature-256"]
      return head :forbidden if signature.blank?

      computed = "sha256=#{OpenSSL::HMAC.hexdigest("SHA256", secret, request_body)}"
      head :forbidden unless ActiveSupport::SecurityUtils.secure_compare(computed, signature)
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
