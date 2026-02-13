module GeneratedDocumentsHelper
  MARKDOWN_ALLOWED_TAGS = %w[
    p br ul ol li strong em a h2 h3 h4 h5 hr blockquote code pre
  ].freeze
  MARKDOWN_ALLOWED_ATTRIBUTES = %w[href title rel target].freeze
  MARKDOWN_ALLOWED_PROTOCOLS = %w[http https mailto].freeze

  def render_generated_markdown(markdown_text)
    html = Commonmarker.to_html(markdown_text.to_s)
    sanitized_html = sanitize(
      html,
      tags: MARKDOWN_ALLOWED_TAGS,
      attributes: MARKDOWN_ALLOWED_ATTRIBUTES
    )

    fragment = Nokogiri::HTML::DocumentFragment.parse(sanitized_html.to_s)
    fragment.css("a").each do |link|
      normalize_generated_link!(link)
    end

    fragment.to_html.html_safe
  end

  private

  def normalize_generated_link!(link)
    href = link["href"].to_s.strip
    return link.remove_attribute("href") if href.blank?

    uri = URI.parse(href)
    scheme = uri.scheme&.downcase

    if scheme.present? && !MARKDOWN_ALLOWED_PROTOCOLS.include?(scheme)
      link.remove_attribute("href")
      link.remove_attribute("target")
      link.remove_attribute("rel")
      return
    end

    if %w[http https].include?(scheme)
      link["target"] = "_blank"
      link["rel"] = "noopener noreferrer"
    else
      link.remove_attribute("target")
      link.remove_attribute("rel")
    end
  rescue URI::InvalidURIError
    link.remove_attribute("href")
    link.remove_attribute("target")
    link.remove_attribute("rel")
  end
end
