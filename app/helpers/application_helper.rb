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

  BLOCK_SANITIZE_TAGS = Rails::HTML::SafeListSanitizer.allowed_tags + %w[img]
  BLOCK_SANITIZE_ATTRS = Rails::HTML::SafeListSanitizer.allowed_attributes + %w[src alt loading class data-permalink target rel]

  def render_blocks(blocks, workspace:)
    sanitize(
      blocks.map { |block| render_block(block, workspace: workspace) }.join,
      tags: BLOCK_SANITIZE_TAGS,
      attributes: BLOCK_SANITIZE_ATTRS
    )
  end

  def render_event_body(event)
    payload = event.payload
    return unless payload.is_a?(Hash)

    workspace = event.slack_channel.workspace
    blocks = payload["blocks"]
    body = if blocks.is_a?(Array) && blocks.any?
      render_blocks(blocks, workspace: workspace)
    elsif payload["text"].present?
      render_markdown(resolve_mentions(payload["text"], workspace: workspace))
    end

    attachments = render_attachments(payload["attachments"], workspace: workspace)
    images = render_event_images(payload, workspace: workspace)
    return body if attachments.blank? && images.blank?

    sanitized_images = images.present? ? sanitize(images, tags: BLOCK_SANITIZE_TAGS, attributes: BLOCK_SANITIZE_ATTRS) : nil
    [body, attachments, sanitized_images].compact_blank.join.html_safe
  end

  def render_event_images(payload, workspace:)
    files = payload["files"]
    return unless files.is_a?(Array)

    images = files.select { |f| f["id"].present? && f["mimetype"]&.start_with?("image/") }
    return if images.empty?

    tags = images.map do |f|
      alt = h(f["name"] || "image")
      permalink = f["permalink"]
      src = workspace_slack_file_proxy_path(workspace, file_id: f["id"])
      img = %(<img src="#{h(src)}" alt="#{alt}" loading="lazy" class="event-image" data-permalink="#{h(permalink)}">)
      if permalink
        %(<a href="#{h(permalink)}" target="_blank" rel="noopener" class="event-image-link">#{img}</a>)
      else
        img
      end
    end

    %(<div class="flex flex-wrap gap-2 mt-2">#{tags.join}</div>)
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

  def slack_image_src(url, workspace:, file_id: nil)
    if file_id.present?
      workspace_slack_file_proxy_path(workspace, file_id: file_id)
    else
      url
    end
  end

  def resolve_mentions(text, workspace:)
    text.gsub(/<@(U[A-Z0-9]+)>/) do
      name = workspace.resolve_user_name($1)
      "@#{name}"
    end.gsub(/<#(C[A-Z0-9]+)(?:\|([^>]*))?>/) do
      name = $2.presence || workspace.slack_channels.find_by(channel_id: $1)&.display_name || $1
      "##{name}"
    end
  end

  def render_attachments(attachments, workspace:)
    return unless attachments.is_a?(Array) && attachments.any?

    attachments.map { |att| render_attachment(att, workspace: workspace) }.compact.join
  end

  def render_attachment(att, workspace:)
    parts = []

    if att["pretext"].present?
      parts << render_markdown(resolve_slack_formatting(att["pretext"], workspace: workspace))
    end

    inner = []

    if att["title"].present?
      inner << %(<div class="font-semibold">#{render_markdown(resolve_slack_formatting(att["title"], workspace: workspace))}</div>)
    end

    if att["text"].present?
      inner << render_markdown(resolve_slack_formatting(att["text"], workspace: workspace))
    end

    if att["footer"].present?
      inner << %(<div class="text-xs text-muted mt-1">#{render_markdown(resolve_slack_formatting(att["footer"], workspace: workspace))}</div>)
    end

    if inner.any?
      color = att["color"]
      style = color ? %( style="border-color: ##{color.gsub(/[^0-9a-fA-F]/, '')}") : ""
      parts << %(<div class="border-l-2 border-muted pl-3 mt-1"#{style}>#{inner.join}</div>)
    end

    return if parts.empty?
    %(<div class="mt-2">#{parts.join}</div>)
  end

  def resolve_slack_formatting(text, workspace:)
    convert_slack_links(resolve_mentions(text, workspace: workspace))
  end

  def convert_slack_links(text)
    text.gsub(/<(https?:\/\/[^|>]+)\|([^>]+)>/) { "[#{$2}](#{$1})" }
        .gsub(/<(https?:\/\/[^>]+)>/) { $1 }
        .gsub(/<mailto:([^|>]+)\|([^>]+)>/) { "[#{$2}](mailto:#{$1})" }
        .gsub(/<mailto:([^>]+)>/) { $1 }
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
      parts = []
      if block["text"]
        text = block.dig("text", "text") || ""
        type = block.dig("text", "type")
        text = resolve_slack_formatting(text, workspace: workspace) if type == "mrkdwn"
        parts << (type == "mrkdwn" ? render_markdown(text) : "<p>#{h(text)}</p>")
      end
      if block["fields"].is_a?(Array)
        fields_html = block["fields"].map do |field|
          text = field["text"] || ""
          text = resolve_slack_formatting(text, workspace: workspace) if field["type"] == "mrkdwn"
          content = field["type"] == "mrkdwn" ? render_markdown(text) : h(text)
          %(<div>#{content}</div>)
        end.join
        parts << %(<div class="grid grid-cols-2 gap-x-4 gap-y-1">#{fields_html}</div>)
      end
      parts.join
    when "header"
      "<strong>#{h(block.dig("text", "text"))}</strong>"
    when "divider"
      "<hr>"
    when "image"
      url = block["image_url"] || block["url"]
      return "" unless url
      alt = h(block["alt_text"] || "image")
      src = slack_image_src(url, workspace: workspace)
      %(<div class="mt-2"><img src="#{h(src)}" alt="#{alt}" loading="lazy" class="event-image"></div>)
    when "actions"
      buttons = (block["elements"] || []).filter_map do |el|
        next unless el["type"] == "button" && el["url"].present?
        label = h(el.dig("text", "text") || "Link")
        %(<a href="#{h(el["url"])}" target="_blank" rel="noopener" class="inline-block text-xs px-3 py-1 rounded border border-border text-muted hover:text-foreground">#{label}</a>)
      end
      buttons.any? ? %(<div class="flex gap-2 mt-1">#{buttons.join}</div>) : ""
    when "context"
      items = (block["elements"] || []).map do |el|
        case el["type"]
        when "image"
          url = el["image_url"] || el["url"]
          if url
            src = slack_image_src(url, workspace: workspace)
            %(<img src="#{h(src)}" alt="#{h(el["alt_text"] || "")}" class="inline-block w-4 h-4 rounded">)
          else
            ""
          end
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
