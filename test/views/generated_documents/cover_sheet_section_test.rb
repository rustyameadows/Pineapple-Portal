require "test_helper"

class CoverSheetSectionTest < ActionView::TestCase
  fixtures :events

  setup do
    @event = events(:one)
    @segment = build_segment

    view.extend DocumentsHelper
    view.extend GeneratedDocumentsHelper
    view.assign(event: @event, segment: @segment)
    view.define_singleton_method(:inline_asset_data_uri) { |_path| "data:image/png;base64,stub" }
    view.define_singleton_method(:inline_font_asset_data_uri) { |_path| "data:font/woff2;base64,stub" }
    view.define_singleton_method(:inline_document_image_data_uri) { |_document| "data:image/png;base64,photo" }
  end

  test "renders a full-height cover with event metadata" do
    render template: "generated_documents/sections/cover_sheet", locals: { render_base_styles: false }

    assert_select ".generated-template--cover", count: 1
    assert_select ".generated-template--cover__document-name", text: @event.name
    assert_select ".generated-template--cover__event-title", text: "Family Packet"
    assert_select ".generated-template--cover__meta", text: /#{Regexp.escape(@event.starts_on.to_fs(:long))}/
    assert_select ".generated-template--cover__meta", text: /#{Regexp.escape(@event.location)}/
    assert_match(/\.generated-template--cover\s*\{[^}]*min-height:\s*100vh/m, rendered)
    assert_match(/\.generated-template--cover\s*\{[^}]*height:\s*11in/m, rendered)
    assert_match(/--page-padding-horizontal:\s*1in/m, rendered)
    assert_match(/--cover-accent:\s*var\(--color-dark-brown,\s*#3f2211\)/m, rendered)
  end

  test "renders the optional event photo when one is attached" do
    render template: "generated_documents/sections/cover_sheet", locals: { render_base_styles: false }

    assert_select ".generated-template--cover__photo img[alt='Launch Event photo']", count: 1
  end

  private

  def build_segment
    DocumentSegment.new(
      kind: DocumentSegment::KINDS[:html_view],
      title: "Family Packet",
      source_ref: {
        "view_key" => "cover_sheet",
        "options" => {}
      },
      spec: {
        "kind" => DocumentSegment::KINDS[:html_view],
        "view_key" => "cover_sheet",
        "label" => "Cover Sheet"
      }
    )
  end
end
