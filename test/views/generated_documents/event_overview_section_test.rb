require "test_helper"

class EventOverviewSectionTest < ActionView::TestCase
  fixtures :events, :event_team_members, :event_vendors, :users

  setup do
    @event = events(:one)
    @segment = build_segment

    view.extend DocumentsHelper
    view.extend GeneratedDocumentsHelper
    view.assign(event: @event, segment: @segment)
    view.define_singleton_method(:inline_asset_data_uri) { |_path| "data:image/png;base64,stub" }
    view.define_singleton_method(:inline_global_asset_data_uri) { |_asset| "data:image/png;base64,avatar" }
  end

  test "renders live event, planner, and vendor data without markdown content" do
    render template: "generated_documents/sections/event_overview", locals: { render_base_styles: false }

    assert_select ".generated-template--event-overview", count: 1
    assert_select ".generated-template--event-overview__event-name", text: @event.name
    assert_select ".generated-template--event-overview__dates", text: "#{@event.starts_on.to_fs(:long)} - #{@event.ends_on.to_fs(:long)}"
    assert_select ".generated-template--event-overview__location", text: @event.location
    assert_select ".generated-template--event-overview__planner-name", text: "Ada Fixture"
    assert_select ".generated-template--event-overview__planner-name", text: "Grace Fixture"
    assert_select ".generated-template--event-overview__planner-title", text: "Lead Planner"
    assert_select ".generated-template--event-overview__planner-title", text: "Operations Director"
    assert_select ".generated-template--event-overview__planner-email", text: /ada_fixture@example.com/
    assert_select ".generated-template--event-overview__planner-phone", text: /555-111-2222/
    assert_select ".generated-template--event-overview__vendor-name", text: "Sunshine Catering"
    assert_select ".generated-template--event-overview__vendor-name", text: "Bright Lights Production"
    assert_select ".generated-template--event-overview__vendor-contact-name", text: /Maria Cater/
    assert_select ".generated-template--event-overview__vendor-contact-email", text: /maria@sunshine.test/
    assert_select ".generated-template--event-overview__vendor-contact-phone", text: /555-123-4567/
    assert_no_match(/Client Contact|Gluten-free specialist/, rendered)
    assert_no_match(/Important Information|Custom Heading|generated-text-columns/, rendered)
  end

  test "ignores markdown options and still renders the live event data layout" do
    @segment = build_segment(
      "## Custom Heading\n\nCustom body copy."
    )
    view.assign(event: @event, segment: @segment)

    render template: "generated_documents/sections/event_overview", locals: { render_base_styles: false }

    assert_select ".generated-template--event-overview__event-name", text: @event.name
    assert_select ".generated-template--event-overview__planner-name", text: "Ada Fixture"
    assert_select ".generated-template--event-overview__vendor-name", text: "Sunshine Catering"
    assert_no_match(/Custom Heading|Custom body copy|generated-text-columns/, rendered)
  end

  test "omits vendors without contact data" do
    @event.event_vendors.create!(
      name: "Silent Vendor",
      vendor_type: "Décor",
      social_handle: "silentvendor",
      contacts_jsonb: [],
      position: 9,
      client_visible: false
    )

    view.assign(event: @event, segment: @segment)
    render template: "generated_documents/sections/event_overview", locals: { render_base_styles: false }

    assert_select ".generated-template--event-overview__vendor-name", text: "Silent Vendor", count: 0
  end

  test "shows empty states when planner and vendor data are missing" do
    empty_event = Event.create!(name: "Quiet Event")

    view.assign(event: empty_event, segment: @segment)
    render template: "generated_documents/sections/event_overview", locals: { render_base_styles: false }

    assert_select ".generated-template--event-overview__dates", text: "Date TBD"
    assert_select ".generated-template--event-overview__location", text: "Location TBD"
    assert_select ".generated-template--event-overview__empty", text: /No planner contacts are linked/
    assert_select ".generated-template--event-overview__empty", text: /No vendor contacts are available/
  end

  private

  def build_segment(body_markdown = nil)
    options = {}
    options["body_markdown"] = body_markdown if body_markdown.present?

    DocumentSegment.new(
      kind: DocumentSegment::KINDS[:html_view],
      title: "Event Info",
      source_ref: {
        "view_key" => DocumentSegment::EVENT_OVERVIEW_VIEW_KEY,
        "options" => options
      },
      spec: {
        "kind" => DocumentSegment::KINDS[:html_view],
        "view_key" => DocumentSegment::EVENT_OVERVIEW_VIEW_KEY,
        "label" => "Event Info"
      }
    )
  end
end
