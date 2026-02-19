class SlackRepliesController < ApplicationController
  def create
    event = SlackEvent.find(params[:slack_event_id])
    channel = event.slack_channel
    workspace = channel.workspace

    args = {
      channel: channel.channel_id,
      text: params[:body]
    }

    if params[:reply_type] == "thread"
      args[:thread_ts] = event.thread_ts || event.ts
    end

    workspace.slack_client.chat_postMessage(**args)

    respond_to do |format|
      format.turbo_stream { head :ok }
      format.html { redirect_to root_path, notice: "Reply sent!" }
    end
  rescue Slack::Web::Api::Errors::SlackError => e
    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: turbo_stream.replace(
          "reply_modal_error",
          html: helpers.content_tag(:div, id: "reply_modal_error") {
            helpers.content_tag(:p, e.message, class: "text-sm text-red-400")
          }
        )
      end
      format.html { redirect_to root_path, alert: e.message }
    end
  end
end
