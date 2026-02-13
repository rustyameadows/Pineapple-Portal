module GeneratedDocumentsHelper
  MARKDOWN_ALLOWED_TAGS = %w[
    p br ul ol li strong em a h2 h3 h4 h5 hr blockquote code pre
  ].freeze
  MARKDOWN_ALLOWED_ATTRIBUTES = %w[href title rel target].freeze
  MARKDOWN_ALLOWED_PROTOCOLS = %w[http https mailto].freeze

  def render_generated_markdown(markdown_text)
    html = render_generated_markdown_segments(markdown_text.to_s)

    fragment = Nokogiri::HTML::DocumentFragment.parse(html.to_s)
    fragment.css("a").each do |link|
      normalize_generated_link!(link)
    end

    fragment.to_html.html_safe
  end

  private

  def render_generated_markdown_segments(markdown_text)
    split_generated_markdown_segments(markdown_text).map do |segment|
      if segment[:type] == :columns
        render_generated_markdown_columns(segment[:columns])
      else
        render_generated_markdown_fragment(segment[:content])
      end
    end.join
  end

  def split_generated_markdown_segments(markdown_text)
    lines = markdown_text.to_s.lines
    segments = []
    markdown_buffer = +""
    index = 0

    while index < lines.length
      if lines[index].strip == ":::columns"
        parsed_block = parse_generated_columns_block(lines, index)
        if parsed_block[:valid]
          segments << { type: :markdown, content: markdown_buffer } if markdown_buffer.present?
          markdown_buffer = +""
          segments << { type: :columns, columns: parsed_block[:columns] }
        else
          markdown_buffer << parsed_block[:raw]
        end

        index = parsed_block[:next_index]
        next
      end

      markdown_buffer << lines[index]
      index += 1
    end

    segments << { type: :markdown, content: markdown_buffer } if markdown_buffer.present?
    segments
  end

  def parse_generated_columns_block(lines, start_index)
    raw = +""
    raw << lines[start_index]
    index = start_index + 1
    columns = []

    while index < lines.length
      line = lines[index]
      raw << line
      stripped = line.strip

      if stripped == ":::column"
        column_parse = parse_generated_column(lines, index + 1)
        raw << column_parse[:raw]
        return invalid_generated_columns_parse(raw, column_parse[:next_index]) unless column_parse[:valid]

        columns << column_parse[:content]
        index = column_parse[:next_index]
        next
      end

      if stripped == ":::"
        return invalid_generated_columns_parse(raw, index + 1) if columns.empty?

        combined_second_column = columns.drop(1).join("\n")
        return {
          valid: true,
          next_index: index + 1,
          columns: [ columns.first.to_s, combined_second_column.to_s ]
        }
      end

      return invalid_generated_columns_parse(raw, index + 1)
    end

    invalid_generated_columns_parse(raw, index)
  end

  def parse_generated_column(lines, start_index)
    content = +""
    raw = +""
    index = start_index

    while index < lines.length
      line = lines[index]
      stripped = line.strip

      if stripped == ":::"
        raw << line
        return { valid: true, next_index: index + 1, content: content, raw: raw }
      end

      raw << line
      content << line
      index += 1
    end

    { valid: false, next_index: index, raw: raw }
  end

  def invalid_generated_columns_parse(raw, next_index)
    { valid: false, next_index: next_index, raw: raw }
  end

  def render_generated_markdown_columns(columns)
    first_column_html = render_generated_markdown_fragment(columns.first.to_s)
    second_column_html = render_generated_markdown_fragment(columns.second.to_s)

    <<~HTML
      <div class="generated-text-columns">
        <div class="generated-text-column">#{first_column_html}</div>
        <div class="generated-text-column">#{second_column_html}</div>
      </div>
    HTML
  end

  def render_generated_markdown_fragment(markdown_text)
    html = Commonmarker.to_html(markdown_text.to_s)
    sanitize(
      html,
      tags: MARKDOWN_ALLOWED_TAGS,
      attributes: MARKDOWN_ALLOWED_ATTRIBUTES
    ).to_s
  end

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
