module ApplicationHelper
  def render_markdown(text)
    renderer = Redcarpet::Render::HTML.new(
      hard_wrap: true,
      no_images: true,
      link_attributes: { target: "_blank", rel: "noopener" }
    )
    markdown = Redcarpet::Markdown.new(renderer,
      autolink: true,
      fenced_code_blocks: true,
      strikethrough: true,
      no_intra_emphasis: true,
      tables: true
    )
    sanitize(markdown.render(emojify(text)))
  end

  def render_blocks(blocks, workspace:)
    sanitize(blocks.map { |block| render_block(block, workspace: workspace) }.join)
  end

  def render_event_body(event)
    payload = event.payload
    return unless payload.is_a?(Hash)

    workspace = event.slack_channel.workspace
    blocks = payload["blocks"]
    if blocks.is_a?(Array) && blocks.any?
      render_blocks(blocks, workspace: workspace)
    elsif payload["text"].present?
      render_markdown(resolve_mentions(payload["text"], workspace: workspace))
    end
  end

  def short_time_ago(time)
    seconds = (Time.current - time).to_i
    return "now" if seconds < 60

    minutes = seconds / 60
    return "#{minutes}m" if minutes < 60

    hours = minutes / 60
    return "#{hours}h" if hours < 24

    days = hours / 24
    return "#{days}d" if days < 7

    weeks = days / 7
    return "#{weeks}w" if days < 30

    months = days / 30
    "#{months}mo"
  end

  private

  def resolve_mentions(text, workspace:)
    text.gsub(/<@(U[A-Z0-9]+)>/) do
      name = workspace.resolve_user_name($1)
      "@#{name}"
    end.gsub(/<#(C[A-Z0-9]+)(?:\|([^>]*))?>/) do
      name = $2.presence || workspace.slack_channels.find_by(channel_id: $1)&.display_name || $1
      "##{name}"
    end
  end

  def find_emoji(name)
    Emoji.find_by_alias(name) || Emoji.find_by_alias(name.sub(/\Alarge_/, ""))
  end

  def emojify(text)
    text.gsub(/:([a-z0-9_+-]+):/) do |match|
      emoji = find_emoji($1)
      emoji ? emoji.raw : match
    end
  end

  def render_block(block, workspace:)
    case block["type"]
    when "rich_text"
      (block["elements"] || []).map { |el| render_block_element(el, workspace: workspace) }.join
    when "section"
      text = block.dig("text", "text") || ""
      type = block.dig("text", "type")
      text = resolve_mentions(text, workspace: workspace) if type == "mrkdwn"
      content = type == "mrkdwn" ? render_markdown(text) : h(text)
      "<p>#{content}</p>"
    when "header"
      "<strong>#{h(block.dig("text", "text"))}</strong>"
    when "divider"
      "<hr>"
    when "context"
      items = (block["elements"] || []).map do |el|
        case el["type"]
        when "image" then ""
        when "mrkdwn" then render_markdown(resolve_mentions(el["text"] || "", workspace: workspace))
        else h(el["text"] || "")
        end
      end.join(" ")
      "<p class=\"text-xs text-muted\">#{items}</p>"
    else
      ""
    end
  end

  def render_block_element(element, workspace:)
    case element["type"]
    when "rich_text_section"
      "<p>#{render_inline_elements(element["elements"] || [], workspace: workspace)}</p>"
    when "rich_text_preformatted"
      "<pre><code>#{render_inline_elements(element["elements"] || [], workspace: workspace)}</code></pre>"
    when "rich_text_quote"
      "<blockquote>#{render_inline_elements(element["elements"] || [], workspace: workspace)}</blockquote>"
    when "rich_text_list"
      tag = element["style"] == "ordered" ? "ol" : "ul"
      items = (element["elements"] || []).map do |item|
        "<li>#{render_inline_elements(item["elements"] || [], workspace: workspace)}</li>"
      end.join
      "<#{tag}>#{items}</#{tag}>"
    else
      ""
    end
  end

  def render_inline_elements(elements, workspace:)
    elements.map { |el| render_inline_element(el, workspace: workspace) }.join
  end

  def render_inline_element(el, workspace:)
    case el["type"]
    when "text"
      text = h(el["text"]).gsub("\n", "<br>")
      style = el["style"] || {}
      text = "<strong>#{text}</strong>" if style["bold"]
      text = "<em>#{text}</em>" if style["italic"]
      text = "<del>#{text}</del>" if style["strike"]
      text = "<code>#{text}</code>" if style["code"]
      text
    when "link"
      text = h(el["text"].presence || el["url"])
      "<a href=\"#{h(el["url"])}\" target=\"_blank\" rel=\"noopener\">#{text}</a>"
    when "emoji"
      if el["unicode"]
        el["unicode"].split("-").map { |cp| cp.to_i(16) }.pack("U*")
      else
        emoji = find_emoji(el["name"])
        emoji ? emoji.raw : ":#{el["name"]}:"
      end
    when "user"
      name = workspace.resolve_user_name(el["user_id"])
      "<strong>@#{h(name)}</strong>"
    when "channel"
      channel = workspace.slack_channels.find_by(channel_id: el["channel_id"])
      name = channel&.display_name || el["channel_id"]
      "<strong>##{h(name)}</strong>"
    else
      ""
    end
  end
end
