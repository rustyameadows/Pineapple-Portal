require "test_helper"

class EventOverviewSectionTest < ActionView::TestCase
  fixtures :events

  setup do
    @event = events(:one)
    @segment = build_segment(nil)

    view.extend DocumentsHelper
    view.extend GeneratedDocumentsHelper
    view.assign(event: @event, segment: @segment)
    view.define_singleton_method(:inline_asset_data_uri) { |_path| "data:image/png;base64,stub" }
  end

  test "renders fallback starter template when markdown options are blank" do
    render template: "generated_documents/sections/event_overview", locals: { render_base_styles: false }

    assert_select ".generated-template--text-page__content h3", text: "Important Information"
    assert_select ".generated-template--text-page__content h3", text: "Vendor Contacts"
    assert_select ".generated-text-columns", minimum: 2
    assert_select ".generated-text-column", minimum: 4
    assert_select ".generated-template--event-overview__vendor-table", count: 0
  end

  test "renders custom markdown when body_markdown is provided" do
    @segment = build_segment("## Custom Heading\n\nCustom body copy.")
    view.assign(event: @event, segment: @segment)

    render template: "generated_documents/sections/event_overview", locals: { render_base_styles: false }

    assert_select ".generated-template--text-page__content h2", text: "Custom Heading"
    assert_select ".generated-template--text-page__content", text: /Custom body copy/
    assert_select ".generated-template--text-page__content h3", text: "Important Information", count: 0
  end

  private

  def build_segment(markdown)
    options = {}
    options["body_markdown"] = markdown unless markdown.nil?

    DocumentSegment.new(
      kind: DocumentSegment::KINDS[:html_view],
      title: "Event Overview",
      source_ref: {
        "view_key" => DocumentSegment::EVENT_OVERVIEW_VIEW_KEY,
        "options" => options
      },
      spec: {
        "kind" => DocumentSegment::KINDS[:html_view],
        "view_key" => DocumentSegment::EVENT_OVERVIEW_VIEW_KEY,
        "label" => "Event Overview"
      }
    )
  end
end
