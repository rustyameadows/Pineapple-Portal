require "test_helper"

class TimelineSectionTest < ActionView::TestCase
  fixtures :events, :users, :event_calendars, :event_calendar_views, :calendar_items

  setup do
    @event = events(:one)
    timeline_view = event_calendar_views(:vendor_view)
    @segment = DocumentSegment.new(
      kind: DocumentSegment::KINDS[:html_view],
      title: "Photo / Video Timeline",
      source_ref: {
        "view_key" => DocumentSegment::TIMELINE_VIEW_KEY,
        "options" => { "view_ref" => timeline_view.id.to_s }
      },
      spec: {
        "kind" => DocumentSegment::KINDS[:html_view],
        "view_key" => DocumentSegment::TIMELINE_VIEW_KEY,
        "label" => "Photo / Video Timeline"
      }
    )

    view.extend DocumentsHelper
    view.extend GeneratedDocumentsHelper
    view.instance_variable_set(:@event, @event)
    view.instance_variable_set(:@segment, @segment)
    view.define_singleton_method(:inline_asset_data_uri) { |_path| "data:image/png;base64,stub" }
    view.define_singleton_method(:inline_font_asset_data_uri) { |_path| "data:font/woff2;base64,stub" }
  end

  test "renders the timeline with the shared packet sheet header style" do
    render template: "generated_documents/sections/timeline"

    assert_select ".generated-template--packet-sheet.generated-template--timeline", count: 1
    assert_select ".generated-template__page-header-title", text: "Photo / Video Timeline", count: 1
    assert_select "table.generated-template--timeline__table", count: 1
    assert_select "table.generated-template--timeline__table thead th", text: "Team", count: 1
    assert_match(/font-family:\s*"Didot"/m, rendered)
    assert_match(/font-family:\s*"BaskervilleNo2"/m, rendered)
  end
end
