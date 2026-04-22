require "test_helper"

class WeddingPartyReferenceSectionTest < ActionView::TestCase
  fixtures :events, :event_calendars, :calendar_items, :event_calendar_tags, :calendar_item_tags, :event_guests

  setup do
    @event = events(:one)
    @segment = DocumentSegment.new(
      kind: DocumentSegment::KINDS[:html_view],
      title: "Wedding Party Reference",
      source_ref: {
        "view_key" => DocumentSegment::WEDDING_PARTY_REFERENCE_VIEW_KEY,
        "options" => {}
      },
      spec: {
        "kind" => DocumentSegment::KINDS[:html_view],
        "view_key" => DocumentSegment::WEDDING_PARTY_REFERENCE_VIEW_KEY,
        "label" => "Wedding Party Reference"
      }
    )

    view.extend DocumentsHelper
    view.extend GeneratedDocumentsHelper
    view.extend CalendarHelper
    view.instance_variable_set(:@event, @event)
    view.instance_variable_set(:@segment, @segment)
    view.define_singleton_method(:inline_asset_data_uri) { |_path| "data:image/png;base64,stub" }
    view.define_singleton_method(:inline_font_asset_data_uri) { |_path| "data:font/woff2;base64,stub" }
  end

  test "renders milestone tagged event items grouped by date, dynamic getting ready details, and key people" do
    milestone_tag = @event.run_of_show_calendar.event_calendar_tags.create!(name: "Milestones", position: 9)
    calendar_items(:decision_flowers).event_calendar_tags << milestone_tag
    calendar_items(:ceremony).event_calendar_tags << milestone_tag
    calendar_items(:afterparty).event_calendar_tags << milestone_tag
    @event.update!(
      getting_ready_details: "Please arrive dressed and ready to prep.\n\nBring all accessories in a labeled bag."
    )

    render template: "generated_documents/sections/wedding_party_reference", locals: { render_base_styles: false }

    assert_select ".generated-template--wedding-party-reference", count: 1
    assert_select ".generated-template--wedding-party-reference__top-band-row", count: 2
    assert_select ".generated-template--wedding-party-reference__events-grid", count: 2
    assert_select ".generated-template--packet-sheet__section-title", text: "Event Timelines"
    assert_select ".generated-template--packet-sheet__section-title", text: "Transportation Details"
    assert_select ".generated-template--wedding-party-reference__transportation-stack", count: 2
    assert_select ".generated-template--wedding-party-reference__transportation-note", text: "Meet in the lobby at 11:30 AM for the florist site visit."
    assert_select ".generated-template--wedding-party-reference__transportation-note", text: "Guests depart from the hotel entrance at 2:15 PM."
    assert_select ".generated-template--packet-sheet__section-title", text: "Getting Ready Details"
    assert_select ".generated-template--packet-sheet__section-title", text: "VIPs & Family", count: 1
    assert_select ".generated-template--packet-sheet__section-title", text: "Wedding Party", count: 0
    assert_select ".generated-template--packet-sheet__section-title", text: "VIP Family", count: 0
    assert_select ".generated-template--packet-sheet__section-title", text: "Jordan's Side", count: 0
    assert_select ".generated-template--wedding-party-reference__wedding-party-columns", count: 1
    assert_select ".generated-template--wedding-party-reference__wedding-party-group", count: 2
    assert_select ".generated-template--wedding-party-reference__wedding-party-group .generated-template--packet-sheet__subsection-title", text: "VIP Family"
    assert_select ".generated-template--wedding-party-reference__wedding-party-group .generated-template--packet-sheet__subsection-title", text: "Jordan's Side"
    assert_match(/generated-template--wedding-party-reference__wedding-party-content\s*\{[^}]*border:\s*1px solid rgba\(0,\s*0,\s*0,\s*0\.06\);/m, rendered)
    assert_match(/generated-template--wedding-party-reference__wedding-party-content\s*\{[^}]*border-top:\s*none;/m, rendered)
    assert_match(/generated-template--wedding-party-reference__wedding-party-columns\s*\{[^}]*align-items:\s*start;/m, rendered)
    assert_match(/generated-template--wedding-party-reference__wedding-party-columns\s*\{[^}]*gap:\s*0\.12in;/m, rendered)
    assert_match(/generated-template--wedding-party-reference__wedding-party-group\s*\{[^}]*align-content:\s*start;/m, rendered)
    assert_no_match(/generated-template--wedding-party-reference__wedding-party-group::after/, rendered)
    assert_match(/generated-template--wedding-party-reference__wedding-party-group \.generated-template--packet-sheet__grid\s*\{[^}]*border-bottom:\s*none;/m, rendered)
    assert_no_match(/generated-template--wedding-party-reference__wedding-party-group \.generated-template--packet-sheet__grid\s*\{[^}]*border-left:\s*none;/m, rendered)
    assert_no_match(/generated-template--wedding-party-reference__wedding-party-group \.generated-template--packet-sheet__grid\s*\{[^}]*border-right:\s*none;/m, rendered)
    assert_match(/generated-template--wedding-party-reference__wedding-party-group \.generated-template--packet-sheet__grid-row:last-child\s*\{[^}]*border-bottom:\s*none;/m, rendered)
    assert_select ".generated-template--packet-sheet__event-card", minimum: 1
    assert_select ".generated-template--packet-sheet__subsection-title", text: "Monday, September 15", count: 2
    assert_select ".generated-template--packet-sheet__subsection-title", text: "Wednesday, October 1", count: 2
    assert_match(/Select Florist/, rendered)
    assert_match(/Ceremony/, rendered)
    assert_match(/Afterparty/, rendered)
    assert_match(/Grand Ballroom/, rendered)
    assert_match(/12:00 PM/, rendered)
    assert_match(/3:00 PM/, rendered)
    assert_match(/9:00 PM.*10:30 PM\*/m, rendered)
    assert_no_match(/Reviewing proposals/, rendered)
    assert_no_match(/Exchange vows and rings\./, rendered)
    assert_match(/Please arrive dressed and ready to prep\./, rendered)
    assert_match(/Bring all accessories in a labeled bag\./, rendered)
    assert_match(/Jordan Rivers/, rendered)
    assert_match(/Maya Chen/, rendered)
    assert_match(/Host/, rendered)
    assert_match(/Sister of the Honoree/, rendered)
    assert_no_match(/Transportation details coming soon\./, rendered)
    assert_no_match(/Hannah Isakowitz/, rendered)
    assert_no_match(/Dan Greener/, rendered)
    assert_no_match(/generated-text-columns|:::columns|### Wedding party reference sheet/, rendered)
  end

  test "keeps transportation column empty for date groups without transportation notes" do
    milestone_tag = @event.run_of_show_calendar.event_calendar_tags.create!(name: "Milestones", position: 9)
    calendar_items(:decision_flowers).event_calendar_tags << milestone_tag
    calendar_items(:decision_catering).event_calendar_tags << milestone_tag
    calendar_items(:ceremony).event_calendar_tags << milestone_tag

    extra_item = @event.run_of_show_calendar.calendar_items.create!(
      title: "Farewell Breakfast",
      starts_at: "2025-10-05 10:00:00",
      duration_minutes: 60,
      locked: false,
      position: 99
    )
    extra_item.event_calendar_tags << milestone_tag

    render template: "generated_documents/sections/wedding_party_reference", locals: { render_base_styles: false }

    assert_select ".generated-template--wedding-party-reference__top-band-row", count: 4
    assert_select ".generated-template--wedding-party-reference__transportation-stack", count: 4
    assert_select ".generated-template--wedding-party-reference__transportation-note", text: "Meet in the lobby at 11:30 AM for the florist site visit.", count: 1
    assert_select ".generated-template--wedding-party-reference__transportation-note", text: "Guests depart from the hotel entrance at 2:15 PM.", count: 1
    assert_select ".generated-template--packet-sheet__subsection-title", text: "Sunday, October 5", count: 2
    assert_no_match(/Transportation details coming soon\./, rendered)
  end

  test "renders rich text transportation details and sanitizes unsafe links" do
    milestone_tag = @event.run_of_show_calendar.event_calendar_tags.create!(name: "Milestones", position: 9)
    ceremony = calendar_items(:ceremony)
    ceremony.event_calendar_tags << milestone_tag
    ceremony.update!(
      transportation_note: "**Guests** board from the *north entrance*.\n\n[Shuttle map](https://example.com/shuttle)\n\n[Unsafe](javascript:alert(1))"
    )

    render template: "generated_documents/sections/wedding_party_reference", locals: { render_base_styles: false }

    assert_select ".generated-template--wedding-party-reference__transportation-note strong", text: "Guests"
    assert_select ".generated-template--wedding-party-reference__transportation-note em", text: "north entrance"
    assert_select ".generated-template--wedding-party-reference__transportation-note a[href='https://example.com/shuttle'][target='_blank'][rel='noopener noreferrer']", text: "Shuttle map"
    assert_match(/generated-template--wedding-party-reference__transportation-note\s*\{\s*gap: 8px;/m, rendered)

    fragment = Nokogiri::HTML::DocumentFragment.parse(rendered)
    unsafe_link = fragment.css(".generated-template--wedding-party-reference__transportation-note a").find { |link| link.text == "Unsafe" }
    assert_not_nil unsafe_link
    assert_nil unsafe_link["href"]
    assert_equal 3, fragment.css(".generated-template--wedding-party-reference__transportation-note p").count
  end

  test "hides getting ready details when blank" do
    empty_event = Event.create!(name: "Quiet Event", getting_ready_details: nil)

    @event = empty_event
    render template: "generated_documents/sections/wedding_party_reference", locals: { render_base_styles: false }

    assert_select ".generated-template--packet-sheet__section-title", text: "Event Timelines"
    assert_select ".generated-template--packet-sheet__empty", text: /No milestone items are available/
    assert_select ".generated-template--packet-sheet__section-title", text: "Transportation Details"
    assert_select ".generated-template--wedding-party-reference__transportation-stack", count: 1
    assert_select ".generated-template--wedding-party-reference__transportation-note", count: 0
    assert_select ".generated-template--packet-sheet__section-title", text: "Getting Ready Details", count: 0
    assert_select ".generated-template--packet-sheet__section-title", text: "Wedding Party", count: 0
    assert_select ".generated-template--packet-sheet__section-title", text: "Oktoberfest Excursions", count: 0
    assert_select ".generated-template--packet-sheet__section-title", text: "Getting Ready Details & Transportation", count: 0
    assert_select ".generated-template--wedding-party-reference__wedding-party-columns", count: 0
  end

  test "falls back to wedding party label when key people label is blank" do
    @event.update!(key_people_label: nil)

    render template: "generated_documents/sections/wedding_party_reference", locals: { render_base_styles: false }

    assert_select ".generated-template--packet-sheet__section-title", text: "Wedding Party", count: 1
  end

  test "renders rich text in getting ready details" do
    @event.update!(
      getting_ready_details: "### Morning Prep\n\n**Arrive** camera-ready.\n\nBring your *labeled bag*.\n\n[Rooming list](https://example.com/rooms)"
    )

    view.instance_variable_set(:@event, @event)
    render template: "generated_documents/sections/wedding_party_reference", locals: { render_base_styles: false }

    assert_select ".generated-template--wedding-party-reference__getting-ready .generated-template--packet-sheet__subsection-title", text: "Morning Prep"
    assert_select ".generated-template--wedding-party-reference__getting-ready strong", text: "Arrive"
    assert_select ".generated-template--wedding-party-reference__getting-ready em", text: "labeled bag"
    assert_select ".generated-template--wedding-party-reference__getting-ready a[href='https://example.com/rooms'][target='_blank'][rel='noopener noreferrer']", text: "Rooming list"
  end
end
