require "test_helper"

class TextPageSectionTest < ActionView::TestCase
  fixtures :events

  setup do
    @event = events(:one)
    @segment = build_segment("## Notes\n\nThis is **important**.\n\n- First item\n- Second item")

    view.extend DocumentsHelper
    view.extend GeneratedDocumentsHelper
    view.assign(event: @event, segment: @segment)
    view.define_singleton_method(:inline_asset_data_uri) { |_path| "data:image/png;base64,stub" }
  end

  test "renders markdown content with formatting" do
    render template: "generated_documents/sections/text_page", locals: { render_base_styles: false }

    assert_select ".generated-template--text-page__content h2", text: "Notes"
    assert_select ".generated-template--text-page__content strong", text: "important"
    assert_select ".generated-template--text-page__content li", text: "First item"
    assert_select ".generated-template--text-page__content li", text: "Second item"
  end

  test "sanitizes unsafe html and link protocols" do
    unsafe_markdown = <<~MD
      [Safe link](https://example.com)
      [Bad link](javascript:alert('x'))
      <script>alert("xss")</script>
      <a href="javascript:alert('xss')">Bad HTML Link</a>
    MD

    @segment = build_segment(unsafe_markdown)
    view.assign(event: @event, segment: @segment)

    render template: "generated_documents/sections/text_page", locals: { render_base_styles: false }

    assert_select "script", count: 0
    assert_select "a[href^='javascript:']", count: 0
    assert_select ".generated-template--text-page__content a[href='https://example.com']", count: 1
  end

  test "shows placeholder when content is blank" do
    @segment = build_segment("")
    view.assign(event: @event, segment: @segment)

    render template: "generated_documents/sections/text_page", locals: { render_base_styles: false }

    assert_select ".generated-template--text-page__empty", text: "Add text in segment settings to populate this page."
  end

  test "renders markdown columns when directives are valid" do
    markdown = <<~MD
      ### Intro

      :::columns
      :::column
      #### Left Side
      Left column details
      :::
      :::column
      #### Right Side
      Right column details
      :::
      :::
    MD

    @segment = build_segment(markdown)
    view.assign(event: @event, segment: @segment)

    render template: "generated_documents/sections/text_page", locals: { render_base_styles: false }

    assert_select ".generated-text-columns", count: 1
    assert_select ".generated-text-column", count: 2
    assert_select ".generated-text-column h4", text: "Left Side"
    assert_select ".generated-text-column h4", text: "Right Side"
  end

  test "keeps a two-column layout when only one markdown column is provided" do
    markdown = <<~MD
      :::columns
      :::column
      Only first column content
      :::
      :::
    MD

    @segment = build_segment(markdown)
    view.assign(event: @event, segment: @segment)

    render template: "generated_documents/sections/text_page", locals: { render_base_styles: false }

    fragment = Nokogiri::HTML::DocumentFragment.parse(rendered)
    columns = fragment.css(".generated-text-column")

    assert_equal 2, columns.size
    assert_includes columns.first.text, "Only first column content"
    assert_equal "", columns.second.text.strip
  end

  test "treats malformed column directives as plain markdown text" do
    markdown = <<~MD
      :::columns
      This should remain literal text.
      :::
    MD

    @segment = build_segment(markdown)
    view.assign(event: @event, segment: @segment)

    render template: "generated_documents/sections/text_page", locals: { render_base_styles: false }

    assert_select ".generated-text-columns", count: 0
    assert_includes rendered, ":::columns"
    assert_includes rendered, "This should remain literal text."
  end

  private

  def build_segment(markdown)
    DocumentSegment.new(
      kind: DocumentSegment::KINDS[:html_view],
      title: "General Notes",
      source_ref: {
        "view_key" => DocumentSegment::TEXT_PAGE_VIEW_KEY,
        "options" => { "body_markdown" => markdown }
      },
      spec: {
        "kind" => DocumentSegment::KINDS[:html_view],
        "view_key" => DocumentSegment::TEXT_PAGE_VIEW_KEY,
        "label" => "Text Page"
      }
    )
  end
end
