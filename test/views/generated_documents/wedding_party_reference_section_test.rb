require "test_helper"

class WeddingPartyReferenceSectionTest < ActionView::TestCase
  fixtures :events, :event_calendars, :calendar_items, :event_calendar_tags, :calendar_item_tags, :event_guests, :event_key_person_groups

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
  end

  test "renders milestones, roster, and auto wedding party timeline columns" do
    milestone_tag = @event.run_of_show_calendar.event_calendar_tags.create!(name: "Milestones", position: 9)
    calendar_items(:decision_flowers).event_calendar_tags << milestone_tag
    calendar_items(:ceremony).event_calendar_tags << milestone_tag
    calendar_items(:afterparty).event_calendar_tags << milestone_tag
    calendar_items(:ceremony).event_calendar_tags << event_calendar_tags(:wedding_party_side_a)
    calendar_items(:afterparty).event_calendar_tags << event_calendar_tags(:wedding_party_side_b)
    @event.update!(getting_ready_details: "Please arrive dressed and ready to prep.\n\nBring all accessories in a labeled bag.")

    render template: "generated_documents/sections/wedding_party_reference", locals: { render_base_styles: false }

    assert_select ".generated-template--wedding-party-reference", count: 1
    assert_select ".generated-template--packet-sheet__section-title", text: "Event Timelines"
    assert_select ".generated-template--packet-sheet__section-title", text: "Transportation Details"
    assert_select ".generated-template--packet-sheet__section-title", text: "Getting Ready Details"
    assert_select ".generated-template--packet-sheet__section-title", text: "VIPs & Family", count: 1
    assert_select ".generated-template--packet-sheet__section-title", text: "Wedding Party Timeline", count: 1
    assert_select ".generated-template--wedding-party-reference__timeline-section", count: 1
    assert_select "table.generated-template--wedding-party-reference__timeline-table", count: 1
    assert_select "table.generated-template--wedding-party-reference__timeline-table thead.generated-template--wedding-party-reference__timeline-column-headers", count: 1
    assert_select "tbody.generated-template--wedding-party-reference__timeline-table-body", count: 1
    assert_select ".generated-template--wedding-party-reference__timeline-column-title", text: "VIP Family", count: 1
    assert_select ".generated-template--wedding-party-reference__timeline-column-title", text: "Jordan's Side", count: 1
    assert_select ".generated-template--wedding-party-reference__timeline-day-title", count: 0
    assert_select ".generated-template--wedding-party-reference__timeline-table-row", minimum: 2
    assert_match(/\.generated-template--wedding-party-reference__timeline-section\s*\{[^}]*break-inside:\s*auto/m, rendered)
    assert_match(/\.generated-template--wedding-party-reference__timeline-table thead\s*\{[^}]*display:\s*table-header-group/m, rendered)
    assert_match(/Ceremony/, rendered)
    assert_match(/Afterparty/, rendered)
    assert_match(/3:00 PM/, rendered)
    timeline_text = css_select(".generated-template--wedding-party-reference__timeline-table-body").map(&:text).join(" ")
    assert_match(/9:00 PM/, timeline_text)
    refute_match(/9:00 PM\*/, timeline_text)
    refute_match(/9:00 PM\s*–\s*10:30 PM\*/, timeline_text)
    assert_match(/Please arrive dressed and ready to prep\./, rendered)
    assert_match(/Jordan Rivers/, rendered)
    assert_match(/Maya Chen/, rendered)
  end

  test "aligns wedding party timeline rows by shared start time" do
    create_timeline_item(
      title: "Bride Only Prep",
      starts_at: "2025-10-01 08:00:00",
      tag: event_calendar_tags(:wedding_party_side_a)
    )
    create_timeline_item(
      title: "Bride Shared Moment",
      starts_at: "2025-10-01 09:00:00",
      tag: event_calendar_tags(:wedding_party_side_a)
    )
    create_timeline_item(
      title: "Groom Shared Moment",
      starts_at: "2025-10-01 09:00:00",
      tag: event_calendar_tags(:wedding_party_side_b)
    )
    create_timeline_item(
      title: "Groom Only Prep",
      starts_at: "2025-10-01 10:00:00",
      tag: event_calendar_tags(:wedding_party_side_b)
    )

    render template: "generated_documents/sections/wedding_party_reference", locals: { render_base_styles: false }

    rows = css_select(".generated-template--wedding-party-reference__timeline-table-row")
    assert_equal 3, rows.count
    assert_match(/8:00 AM\s*Bride Only Prep/, rows.first.text)
    refute_match(/Groom Only Prep/, rows.first.text)
    assert_match(/9:00 AM\s*Bride Shared Moment\s*9:00 AM\s*Groom Shared Moment/, rows[1].text)
    assert_match(/10:00 AM\s*Groom Only Prep/, rows[2].text)
    refute_match(/Bride Only Prep/, rows[2].text)
    assert_select ".generated-template--wedding-party-reference__timeline-slot--empty", count: 2
    refute_match(/8:00 AM\s*–\s*8:30 AM/, rendered)
  end

  test "preserves line breaks in wedding party timeline item notes" do
    create_timeline_item(
      title: "Holding Area Move",
      starts_at: "2025-10-01 14:10:00",
      tag: event_calendar_tags(:wedding_party_side_a),
      notes: "Maggie, Kathy, Bridesmaids: Bridal Room\nWill and his parents: Groom's Room\nGroomsmen: ready with programs"
    )

    render template: "generated_documents/sections/wedding_party_reference", locals: { render_base_styles: false }

    notes = css_select(".generated-template--wedding-party-reference__timeline-notes")
    assert_equal 1, notes.count
    assert_includes notes.first.to_html, "<br"
    assert_match(/Maggie, Kathy, Bridesmaids: Bridal Room\s*Will and his parents: Groom's Room\s*Groomsmen: ready with programs/, notes.first.text)
  end

  test "renders manual timeline columns with multi-day grouping and tag-name fallback labels" do
    calendar_items(:decision_flowers).event_calendar_tags << event_calendar_tags(:day_of)
    @segment = build_segment(
      "timeline_mode" => "manual",
      "timeline_tag_ids" => [
        event_calendar_tags(:vendor).id,
        event_calendar_tags(:day_of).id
      ]
    )
    view.instance_variable_set(:@segment, @segment)

    render template: "generated_documents/sections/wedding_party_reference", locals: { render_base_styles: false }

    assert_select ".generated-template--wedding-party-reference__timeline-column-title", text: "Vendor", count: 2
    assert_select ".generated-template--wedding-party-reference__timeline-column-title", text: "Day Of", count: 2
    assert_select ".generated-template--wedding-party-reference__timeline-day-title", text: "Monday, September 15", count: 1
    assert_select ".generated-template--wedding-party-reference__timeline-day-title", text: "Wednesday, October 1", count: 1
    assert_match(/Select Florist/, rendered)
    assert_match(/Reception/, rendered)
    assert_match(/Afterparty/, rendered)
  end

  test "keeps empty selected columns visible and renders items in every matching column" do
    calendar_items(:reception).event_calendar_tags << event_calendar_tags(:wedding_party_side_a)
    @segment = build_segment(
      "timeline_mode" => "manual",
      "timeline_tag_ids" => [
        event_calendar_tags(:vendor).id,
        event_calendar_tags(:wedding_party_side_a).id,
        event_calendar_tags(:day_of).id
      ]
    )
    view.instance_variable_set(:@segment, @segment)

    render template: "generated_documents/sections/wedding_party_reference", locals: { render_base_styles: false }

    assert_equal 2, rendered.scan(/Reception/).count
    assert_select ".generated-template--wedding-party-reference__timeline-column-title", text: "VIP Family", count: 1
    assert_select ".generated-template--wedding-party-reference__timeline-column-title", text: "Vendor", count: 1
    assert_select ".generated-template--wedding-party-reference__timeline-column-title", text: "Day Of", count: 1
    assert_select ".generated-template--wedding-party-reference__timeline-empty", text: "No timeline items.", count: 1
  end

  test "falls back to auto columns when manual selection no longer resolves" do
    calendar_items(:ceremony).event_calendar_tags << event_calendar_tags(:wedding_party_side_a)
    @segment = build_segment(
      "timeline_mode" => "manual",
      "timeline_tag_ids" => [999_999]
    )
    view.instance_variable_set(:@segment, @segment)

    render template: "generated_documents/sections/wedding_party_reference", locals: { render_base_styles: false }

    assert_select ".generated-template--wedding-party-reference__timeline-column-title", text: "VIP Family", count: 1
    assert_select ".generated-template--wedding-party-reference__timeline-column-title", text: "Jordan's Side", count: 1
    assert_match(/Ceremony/, rendered)
  end

  test "shows a section-level empty state when no sides exist yet" do
    @event = Event.create!(name: "Quiet Event", getting_ready_details: nil)
    view.instance_variable_set(:@event, @event)
    view.instance_variable_set(:@segment, build_segment)

    render template: "generated_documents/sections/wedding_party_reference", locals: { render_base_styles: false }

    assert_select ".generated-template--packet-sheet__section-title", text: "Wedding Party Timeline", count: 1
    assert_select ".generated-template--packet-sheet__empty", text: "Create a key-person side to show an automatic wedding party timeline column.", count: 1
  end

  private

  def build_segment(options = {})
    DocumentSegment.new(
      kind: DocumentSegment::KINDS[:html_view],
      title: "Wedding Party Reference",
      source_ref: {
        "view_key" => DocumentSegment::WEDDING_PARTY_REFERENCE_VIEW_KEY,
        "options" => options
      },
      spec: {
        "kind" => DocumentSegment::KINDS[:html_view],
        "view_key" => DocumentSegment::WEDDING_PARTY_REFERENCE_VIEW_KEY,
        "label" => "Wedding Party Reference"
      }
    )
  end

  def create_timeline_item(title:, starts_at:, tag:, duration_minutes: 30, notes: nil)
    item = @event.run_of_show_calendar.calendar_items.create!(
      title: title,
      notes: notes,
      starts_at: starts_at,
      duration_minutes: duration_minutes,
      position: @event.run_of_show_calendar.calendar_items.maximum(:position).to_i + 1
    )
    item.event_calendar_tags << tag
    item
  end
end
