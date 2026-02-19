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
    sanitize(markdown.render(text))
  end
end
