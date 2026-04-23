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
    event_dates = if @event.starts_on.present?
                    if @event.ends_on.present? && @event.ends_on != @event.starts_on
                      "#{@event.starts_on.to_fs(:long)} - #{@event.ends_on.to_fs(:long)}"
                    else
                      @event.starts_on.to_fs(:long)
                    end
                  end

    render template: "generated_documents/sections/cover_sheet", locals: { render_base_styles: false }

    assert_select ".generated-template--cover", count: 1
    assert_select ".generated-template--cover__event-name", text: @event.name
    assert_select ".generated-template--cover__document-title", text: "Family Packet"
    assert_select ".generated-template--cover__event-date", text: event_dates
    assert_select ".generated-template--cover__event-location", text: @event.location
    assert_select ".generated-template--cover__divider img[aria-hidden='true']", count: 1
    assert_match(/\.generated-template--cover\s*\{[^}]*height:\s*11in/m, rendered)
    assert_match(/--page-padding-horizontal:\s*0\.7in/m, rendered)
    assert_match(/--cover-bg:\s*var\(--color-white,\s*#ffffff\)/m, rendered)
    assert_match(/--cover-accent:\s*var\(--color-dark-brown,\s*#3f2211\)/m, rendered)
    assert_match(/\.generated-template--cover\s+\.generated-template--cover__event-name\s*\{[^}]*font-size:\s*0\.35in/m, rendered)
    assert_match(/\.generated-template--cover\s+\.generated-template--cover__event-name,[^}]*\.generated-template--cover\s+\.generated-template--cover__document-title\s*\{[^}]*margin:\s*0/m, rendered)
    assert_match(/\.generated-template--cover\s+\.generated-template--cover__event-date,[^}]*font-size:\s*0\.2in/m, rendered)
    assert_match(/\.generated-template--cover\s+\.generated-template--cover__document-title\s*\{[^}]*font-size:\s*0\.20in/m, rendered)
  end

  test "renders the optional event photo when one is attached" do
    render template: "generated_documents/sections/cover_sheet", locals: { render_base_styles: false }

    assert_select ".generated-template--cover__photo img[alt='Launch Event photo']", count: 1
    assert_match(/\.generated-template--cover__photo img\s*\{[^}]*width:\s*70%/m, rendered)
    assert_match(/\.generated-template--cover__photo img\s*\{[^}]*border:\s*2px solid var\(--cover-accent\)/m, rendered)
  end

  test "omits the event photo container when no photo is attached" do
    view.define_singleton_method(:inline_document_image_data_uri) { |_document| nil }

    render template: "generated_documents/sections/cover_sheet", locals: { render_base_styles: false }

    assert_select ".generated-template--cover__photo", count: 0
    assert_select ".generated-template--cover__details", count: 1
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
