require "test_helper"

class EventOverviewSectionTest < ActionView::TestCase
  include CalendarHelper
  include GeneratedDocumentsHelper

  fixtures :events, :event_calendars, :calendar_items, :event_calendar_tags, :calendar_item_tags, :event_team_members, :event_vendors, :event_guests, :users

  setup do
    @event = events(:one)
    @segment = build_segment

    view.extend DocumentsHelper
    view.extend GeneratedDocumentsHelper
    view.extend CalendarHelper
    view.instance_variable_set(:@event, @event)
    view.instance_variable_set(:@segment, @segment)
    view.define_singleton_method(:inline_asset_data_uri) { |_path| "data:image/png;base64,stub" }
    view.define_singleton_method(:inline_font_asset_data_uri) { |_path| "data:font/woff2;base64,stub" }
    view.define_singleton_method(:inline_global_asset_data_uri) { |_asset| "data:image/png;base64,avatar" }
  end

  test "renders live event, planner, timeline, and vendor data without markdown content" do
    milestone_tag = @event.run_of_show_calendar.event_calendar_tags.create!(name: "Milestones", position: 9)
    calendar_items(:decision_flowers).event_calendar_tags << milestone_tag
    calendar_items(:ceremony).event_calendar_tags << milestone_tag
    calendar_items(:reception).event_calendar_tags << milestone_tag
    calendar_items(:afterparty).event_calendar_tags << milestone_tag
    calendar_items(:ceremony).update!(guest_count: "150 guests")
    calendar_items(:reception).update!(location_name: "Terrace Garden", guest_count: "175 guests")
    event_venues(:main_hall).update!(address: "123 Pineapple Ave\nSuite 100")
    event_venues(:backup_space).update!(address: "456 Terrace Road\nGarden Level")

    render template: "generated_documents/sections/event_overview", locals: { render_base_styles: false }

    assert_select ".generated-template--event-overview", count: 1
    assert_select ".generated-template--packet-sheet", count: 1
    assert_select ".generated-template--packet-sheet__grid", minimum: 4
    assert_select ".generated-template--packet-sheet__section-title", text: "Important Information"
    assert_select ".generated-template--packet-sheet__section-title", text: "Timeline"
    assert_select ".generated-template--packet-sheet__section-title", text: "Venue Addresses"
    assert_select ".generated-template--packet-sheet__section-title", text: "Social Media Handles"
    assert_includes rendered, "grid-template-columns: repeat(4, minmax(0, 1fr));"
    assert_match(/\.generated-template--packet-sheet\s*\{[^}]*gap:\s*8px/m, rendered)
    assert_match(/\.generated-template--packet-sheet\s*\{[^}]*--generated-document-content-padding-bottom:\s*0\.275in/m, rendered)
    assert_match(/\.generated-template--packet-sheet \.generated-template__page-header\s*\{[^}]*padding-bottom:\s*4px/m, rendered)
    assert_match(/\.generated-template--packet-sheet \.generated-template__page-header-title\s*\{[^}]*margin-bottom:\s*2px/m, rendered)
    assert_match(/\.generated-template--packet-sheet__stack,\s*\.generated-template--packet-sheet__one-column\s*\{[^}]*gap:\s*8px/m, rendered)
    assert_match(/\.generated-template--event-overview__important-information-groups\s*\{[^}]*gap:\s*4px/m, rendered)
    assert_select ".generated-template--event-overview__event-name", count: 0
    assert_select ".generated-template--event-overview__dates", text: "#{@event.starts_on.to_fs(:long)} - #{@event.ends_on.to_fs(:long)}"
    assert_select ".generated-template--event-overview__location", text: @event.location
    assert_select ".generated-template--event-overview__guest-count", text: @event.guest_count
    assert_select ".generated-template--packet-sheet__text--label", text: "Host"
    assert_select ".generated-template--packet-sheet__text--value", text: "Jordan Rivers"
    assert_select ".generated-template--packet-sheet__text--label", text: "Sister of the Honoree", count: 0
    assert_select ".generated-template--event-overview__important-information-groups .generated-template--packet-sheet__subsection", minimum: 3
    assert_select ".generated-template--packet-sheet__text--label", text: "Attire"
    assert_select ".generated-template--packet-sheet__text--value", text: @event.attire
    assert_select ".generated-template--packet-sheet__text--label", text: "Color Palette"
    assert_select ".generated-template--packet-sheet__text--value", text: @event.color_palette
    assert_select ".generated-template--packet-sheet__text--label", text: "Style"
    assert_select ".generated-template--packet-sheet__text--value", text: @event.style
    assert_select ".generated-template--event-overview__timeline-groups", count: 1
    assert_match(/\.generated-template--event-overview__timeline-groups\s*\{[^}]*gap:\s*0/m, rendered)
    assert_select ".generated-template--event-overview__timeline-group", count: 2
    assert_select ".generated-template--event-overview__timeline-date", text: "Monday, September 15"
    assert_select ".generated-template--event-overview__timeline-date", text: "Wednesday, October 1"
    assert_select ".generated-template--event-overview__timeline-grid", count: 2
    assert_select ".generated-template--event-overview__timeline-card", count: 4
    assert_select ".generated-template--event-overview__timeline-title", text: "Select Florist"
    assert_select ".generated-template--event-overview__timeline-title", text: "Ceremony"
    assert_select ".generated-template--event-overview__timeline-title", text: "Reception"
    assert_select ".generated-template--event-overview__timeline-title", text: "Afterparty"
    assert_select ".generated-template--event-overview__timeline-location", text: "Grand Ballroom"
    assert_select ".generated-template--event-overview__timeline-location", text: "Terrace Garden"
    assert_select "u.generated-template--event-overview__timeline-time", text: calendar_item_time_only_label_with_marker(calendar_items(:ceremony), @event.run_of_show_calendar.timezone)
    assert_select "u.generated-template--event-overview__timeline-time", text: calendar_item_time_only_label_with_marker(calendar_items(:reception), @event.run_of_show_calendar.timezone)
    assert_select "u.generated-template--event-overview__timeline-time", text: calendar_item_time_only_label_with_marker(calendar_items(:afterparty), @event.run_of_show_calendar.timezone)
    assert_select "em.generated-template--event-overview__timeline-guest-count", text: "150 guests"
    assert_select "em.generated-template--event-overview__timeline-guest-count", text: "175 guests"
    assert_select "em.generated-template--event-overview__timeline-guest-count", count: 2
    assert_select ".generated-template--event-overview__venue-address-grid", count: 1
    assert_select ".generated-template--event-overview__venue-address-card", count: 2
    assert_select ".generated-template--event-overview__venue-address-name strong", text: "Grand Ballroom"
    assert_select ".generated-template--event-overview__venue-address-name strong", text: "Terrace Garden"
    assert_select ".generated-template--event-overview__venue-address", text: /123 Pineapple Ave\s+Suite 100/
    assert_select ".generated-template--event-overview__venue-address", text: /456 Terrace Road\s+Garden Level/
    assert_select ".generated-template--event-overview__social-media-category", text: "Planning, Design & Coordination"
    assert_select ".generated-template--event-overview__social-media-row", count: 3
    assert_match(/\.generated-template--event-overview__social-media-row\s*\{[^}]*grid-template-columns:\s*1\.35fr 1\.8fr 1\.15fr/m, rendered)
    assert_select ".generated-template--event-overview__social-media-company", text: "Pineapple Productions"
    assert_select ".generated-template--event-overview__social-media-company", text: "Sunshine Catering"
    assert_select ".generated-template--event-overview__social-media-company", text: "Bright Lights Production"
    assert_select ".generated-template--event-overview__social-media-handle", text: "@pineappleprodc"
    assert_select ".generated-template--event-overview__social-media-handle", text: "@sunshinecatering"
    assert_select ".generated-template--event-overview__social-media-handle", text: "@brightlights"
    assert_select ".generated-template--event-overview__vendor-contact-name", count: 0
    assert_select ".generated-template--event-overview__vendor-contact-name--empty", count: 0
    assert_no_match(/Ada Fixture|Maria Cater|Leo Light/, rendered)
    assert_select ".generated-template--event-overview__vendor-contact-phone", count: 0
    assert_select ".generated-template--event-overview__vendor-contact-email", count: 0
    assert_select ".generated-template--packet-sheet__section-title", text: "Social Media Policy"
    assert_select ".generated-template--event-overview__social-media", text: @event.social_media_policy
    assert_select ".generated-template--packet-sheet__section-title", text: "PARKING & GETTING THERE"
    assert_select ".generated-template--event-overview__parking", text: @event.parking_details
    assert_operator rendered.index("Timeline"), :<, rendered.index("Venue Addresses")
    assert_operator rendered.index("Venue Addresses"), :<, rendered.index("Social Media Handles")
    assert_operator rendered.index("Social Media Handles"), :<, rendered.index("Social Media Policy")
    assert_operator rendered.index("Social Media Policy"), :<, rendered.index("PARKING &amp; GETTING THERE")
    assert_no_match(/555-123-4567|555-987-6543/, rendered)
    assert_no_match(/Client Contact|Gluten-free specialist/, rendered)
    assert_no_match(/Custom Heading|generated-text-columns/, rendered)
  end

  test "ignores markdown options and still renders the live event data layout" do
    @segment = build_segment(
      "## Custom Heading\n\nCustom body copy."
    )
    view.instance_variable_set(:@event, @event)
    view.instance_variable_set(:@segment, @segment)

    render template: "generated_documents/sections/event_overview", locals: { render_base_styles: false }

    assert_select ".generated-template--event-overview__event-name", count: 0
    assert_select ".generated-template--event-overview__guest-count", text: @event.guest_count
    assert_select ".generated-template--packet-sheet__text--value", text: "Jordan Rivers"
    assert_select ".generated-template--event-overview__social-media-company", text: "Pineapple Productions"
    assert_select ".generated-template--event-overview__social-media-company", text: "Sunshine Catering"
    assert_no_match(/Custom Heading|Custom body copy|generated-text-columns/, rendered)
  end

  test "renders canonical global vendor identity with the event type override" do
    vendor = event_vendors(:catering)
    vendor.update_columns(
      name: "Legacy Event Vendor Name",
      social_handle: "@legacy-event-handle",
      vendor_type: "Reception Catering"
    )
    vendor.global_vendor.update!(
      name: "Sunshine Hospitality",
      default_social_handle: "sunshinehospitality"
    )

    render template: "generated_documents/sections/event_overview", locals: { render_base_styles: false }

    assert_select ".generated-template--event-overview__social-media-category", text: "Reception Catering"
    assert_select ".generated-template--event-overview__social-media-company", text: "Sunshine Hospitality"
    assert_select ".generated-template--event-overview__social-media-handle", text: "@sunshinehospitality"
    assert_no_match(/Legacy Event Vendor Name|legacy-event-handle/, rendered)
  end

  test "includes vendors without contact data" do
    silent_vendor = GlobalVendor.create!(
      name: "Silent Vendor",
      default_social_handle: "silentvendor"
    )
    @event.event_vendors.create!(
      global_vendor: silent_vendor,
      vendor_type: "Décor",
      position: 9,
      client_visible: false
    )
    type_free_vendor = GlobalVendor.create!(
      name: "Type Free Vendor",
      default_social_handle: "typefree",
      contacts_attributes: [ { name: "No Type Contact" } ]
    )
    @event.event_vendors.create!(
      global_vendor: type_free_vendor,
      vendor_type: nil,
      position: 10,
      client_visible: false
    )

    view.assign(event: @event, segment: @segment)
    render template: "generated_documents/sections/event_overview", locals: { render_base_styles: false }

    assert_select ".generated-template--event-overview__social-media-company", text: "Silent Vendor"
    assert_select ".generated-template--event-overview__social-media-company", text: "Type Free Vendor"
    assert_select ".generated-template--event-overview__vendor-contact-name", count: 0
    assert_no_match(/No Type Contact/, rendered)
    assert_no_match(/generated-template--packet-sheet__text--label">Vendor<\/p>/, rendered)
  end

  test "shows empty states when planner and vendor data are missing" do
    empty_event = Event.create!(name: "Quiet Event")

    @event = empty_event
    render template: "generated_documents/sections/event_overview", locals: { render_base_styles: false }

    assert_select ".generated-template--event-overview__dates", text: "Date TBD"
    assert_select ".generated-template--event-overview__location", text: "Location TBD"
    assert_select ".generated-template--packet-sheet__section-title", text: "Timeline"
    assert_select ".generated-template--packet-sheet__section-title", text: "Venue Addresses"
    assert_select ".generated-template--packet-sheet__section-title", text: "Social Media Handles"
    assert_select ".generated-template--packet-sheet__empty", text: /No milestone items are available/
    assert_select ".generated-template--packet-sheet__empty", text: /No venue addresses are available/
    assert_select ".generated-template--packet-sheet__empty", text: /No social media handles are available/
    assert_select ".generated-template--event-overview__guest-count", count: 0
    assert_select ".generated-template--packet-sheet__text--label", text: "Host", count: 0
    assert_select ".generated-template--packet-sheet__text--label", text: "Attire", count: 0
    assert_select ".generated-template--packet-sheet__section-title", text: "Social Media Policy", count: 0
    assert_select ".generated-template--packet-sheet__section-title", text: "PARKING & GETTING THERE", count: 0
  end

  test "renders a single venue address with singular heading and full width grid" do
    event_venues(:main_hall).update!(address: "123 Pineapple Ave\nSuite 100")

    render template: "generated_documents/sections/event_overview", locals: { render_base_styles: false }

    assert_select ".generated-template--packet-sheet__section-title", text: "Venue Address", count: 1
    assert_select ".generated-template--packet-sheet__section-title", text: "Venue Addresses", count: 0
    assert_select ".generated-template--event-overview__venue-address-grid--single", count: 1
    assert_select ".generated-template--event-overview__venue-address-card", count: 1
    assert_select ".generated-template--event-overview__venue-address-name strong", text: "Grand Ballroom"
    assert_select ".generated-template--event-overview__venue-address", text: /123 Pineapple Ave\s+Suite 100/
  end

  test "hides empty metadata rows and sections while keeping populated rows" do
    @event.update!(
      guest_count: nil,
      attire: nil,
      color_palette: nil,
      style: "Minimal Modern",
      social_media_policy: "",
      parking_details: nil
    )

    view.instance_variable_set(:@event, @event)
    view.instance_variable_set(:@segment, @segment)
    render template: "generated_documents/sections/event_overview", locals: { render_base_styles: false }

    assert_select ".generated-template--event-overview__guest-count", count: 0
    assert_select ".generated-template--packet-sheet__text--label", text: "Host", count: 1
    assert_select ".generated-template--packet-sheet__text--value", text: "Jordan Rivers"
    assert_select ".generated-template--packet-sheet__text--label", text: "Attire", count: 0
    assert_select ".generated-template--packet-sheet__text--label", text: "Color Palette", count: 0
    assert_select ".generated-template--packet-sheet__text--label", text: "Style", count: 1
    assert_select ".generated-template--packet-sheet__text--value", text: "Minimal Modern"
    assert_select ".generated-template--packet-sheet__section-title", text: "Social Media Policy", count: 0
    assert_select ".generated-template--packet-sheet__section-title", text: "PARKING & GETTING THERE", count: 0
  end

  test "renders rich text in social media and parking sections" do
    @event.update!(
      social_media_policy: "### Posting Guidelines\n\n**Please** hold posts until *after* the ceremony.\n\n[Approved channels](https://example.com/social)",
      parking_details: "### Arrival Notes\n\nValet is available at the west entrance.\n\n[Parking map](https://example.com/parking)"
    )

    view.instance_variable_set(:@event, @event)
    render template: "generated_documents/sections/event_overview", locals: { render_base_styles: false }

    assert_select ".generated-template--event-overview__social-media .generated-template--packet-sheet__subsection-title", text: "Posting Guidelines"
    assert_select ".generated-template--event-overview__social-media strong", text: "Please"
    assert_select ".generated-template--event-overview__social-media em", text: "after"
    assert_select ".generated-template--event-overview__social-media a[href='https://example.com/social'][target='_blank'][rel='noopener noreferrer']", text: "Approved channels"
    assert_select ".generated-template--event-overview__parking .generated-template--packet-sheet__subsection-title", text: "Arrival Notes"
    assert_select ".generated-template--event-overview__parking a[href='https://example.com/parking'][target='_blank'][rel='noopener noreferrer']", text: "Parking map"
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
