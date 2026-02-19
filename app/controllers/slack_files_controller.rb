class SlackFilesController < ApplicationController
  def show
    workspace = Workspace.find(params[:workspace_id])
    file_id = params[:file_id]

    file_data = find_file_in_events(workspace, file_id)
    return head :not_found unless file_data

    url = file_data["url_private_download"] || file_data["url_private"]
    return head :not_found unless url

    response = fetch_with_redirects(url, token: workspace.user_token)

    if response.is_a?(Net::HTTPSuccess) && response["content-type"]&.start_with?("image/")
      expires_in 1.hour, public: true
      send_data response.body,
        type: response["content-type"],
        disposition: "inline"
    else
      head :not_found
    end
  end

  private

  MAX_REDIRECTS = 5

  def find_file_in_events(workspace, file_id)
    workspace.slack_channels.joins(:slack_events).merge(
      SlackEvent.where("json_extract(payload, '$.files') IS NOT NULL")
    ).find_each do |channel|
      channel.slack_events.each do |event|
        files = event.payload&.dig("files")
        next unless files.is_a?(Array)
        found = files.find { |f| f["id"] == file_id }
        return found if found
      end
    end
    nil
  end

  def fetch_with_redirects(url, token:, limit: MAX_REDIRECTS)
    return nil if limit == 0

    uri = URI.parse(url)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    request = Net::HTTP::Get.new(uri)
    request["Authorization"] = "Bearer #{token}" if uri.host.end_with?(".slack.com")

    response = http.request(request)

    if response.is_a?(Net::HTTPRedirection)
      location = response["location"]
      location = URI.join(url, location).to_s unless location.start_with?("http")
      fetch_with_redirects(location, token: token, limit: limit - 1)
    else
      response
    end
  end
end
