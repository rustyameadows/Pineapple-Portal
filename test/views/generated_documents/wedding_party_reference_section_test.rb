require "test_helper"

class WeddingPartyReferenceSectionTest < ActionView::TestCase
  fixtures :events, :event_calendars, :calendar_items, :event_calendar_tags, :calendar_item_tags

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
  end

  test "renders milestone tagged event items grouped by date and dynamic getting ready details" do
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
    assert_select ".generated-template--packet-sheet__section-title", text: "Getting Ready Details"
    assert_select ".generated-template--packet-sheet__section-title", text: "Bride's Side"
    assert_select ".generated-template--packet-sheet__section-title", text: "Groom's Side"
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
    assert_match(/Reviewing proposals/, rendered)
    assert_match(/Exchange vows and rings\./, rendered)
    assert_match(/Guests attending the Rehearsal should meet/, rendered)
    assert_match(/Please arrive dressed and ready to prep\./, rendered)
    assert_match(/Bring all accessories in a labeled bag\./, rendered)
    assert_match(/Hannah Isakowitz/, rendered)
    assert_match(/Dan Greener/, rendered)
    assert_no_match(/generated-text-columns|:::columns|### Wedding party reference sheet/, rendered)
  end

  test "shows placeholder transportation copy when live milestone groups exceed stub day groups" do
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
    assert_select ".generated-template--packet-sheet__subsection-title", text: "Sunday, October 5", count: 2
    assert_match(/Transportation details coming soon\./, rendered)
  end

  test "hides getting ready details when blank" do
    empty_event = Event.create!(name: "Quiet Event", getting_ready_details: nil)

    @event = empty_event
    render template: "generated_documents/sections/wedding_party_reference", locals: { render_base_styles: false }

    assert_select ".generated-template--packet-sheet__section-title", text: "Event Timelines"
    assert_select ".generated-template--packet-sheet__empty", text: /No milestone items are available/
    assert_select ".generated-template--packet-sheet__section-title", text: "Transportation Details"
    assert_select ".generated-template--packet-sheet__empty", text: /Transportation details coming soon\./
    assert_select ".generated-template--packet-sheet__section-title", text: "Getting Ready Details", count: 0
    assert_select ".generated-template--packet-sheet__section-title", text: "Oktoberfest Excursions", count: 0
    assert_select ".generated-template--packet-sheet__section-title", text: "Getting Ready Details & Transportation", count: 0
    assert_select ".generated-template--packet-sheet__section-title", text: "Bride's Side"
    assert_select ".generated-template--packet-sheet__section-title", text: "Groom's Side"
  end
end
