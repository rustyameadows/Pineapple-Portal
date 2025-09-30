require "test_helper"

class EventOverviewSectionTest < ActionView::TestCase
  fixtures :events, :event_vendors

  setup do
    @event = events(:one)
    @segment = DocumentSegment.new(title: "Event Overview")
    view.extend DocumentsHelper
    view.assign(event: @event, segment: @segment)
    view.define_singleton_method(:inline_asset_data_uri) { |_path| "data:image/png;base64,stub" }
  end

  test "renders vendor contacts table with vendor and social" do
    render template: "generated_documents/sections/event_overview", locals: { render_base_styles: false }

    assert_select "table.generated-template--event-overview__vendor-table" do
      assert_select "th", text: "Vendor Type"
      assert_select "td", text: "Catering"
      assert_select "td", text: "Lighting"
      assert_select "span.generated-template--event-overview__vendor-name", text: "Sunshine Catering"

      socials = css_select("span.generated-template--event-overview__vendor-social").map { |node| node.text.strip }
      assert_includes socials, "sunshinecatering"
      assert_includes socials, "@brightlights"
    end
  end

  test "shows placeholder when no vendors" do
    EventVendor.delete_all
    EventVenue.delete_all
    @event = Event.find(@event.id)
    view.assign(event: @event, segment: @segment)

    render template: "generated_documents/sections/event_overview", locals: { render_base_styles: false }

    assert_select ".generated-template--event-overview__empty", text: "Vendor list coming soon."
  end
end
