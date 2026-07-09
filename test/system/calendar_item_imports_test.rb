require "application_system_test_case"

class CalendarItemImportsTest < ApplicationSystemTestCase
  setup do
    @destination_event = events(:two)
    @source_event = events(:one)
    @ceremony = calendar_items(:ceremony)
    @destination_event.event_team_members.find_or_create_by!(
      user: users(:one),
      member_role: EventTeamMember::TEAM_ROLES[:planner]
    )
  end

  test "planner preview updates when the anchor date changes and the dialog mirrors the projection" do
    login_as_planner
    visit event_calendar_item_import_path(@destination_event, source_event_id: @source_event.id, source_timeline_ref: "run_of_show")

    assert_equal @destination_event.starts_on.to_s, find_field("Anchor date").value

    find("input##{ActionView::RecordIdentifier.dom_id(@ceremony, :import_selection)}", visible: :all).set(true)

    within ".event-calendars__import-preview-table-shell" do
      assert_text "Ceremony"
      assert_text "Nov 15 • 11:00 AM – 11:45 AM"
    end

    page.execute_script(<<~JS)
      const input = document.querySelector("input[name='anchor_date']")
      input.value = "2025-11-20"
      input.dispatchEvent(new Event("input", { bubbles: true }))
      input.dispatchEvent(new Event("change", { bubbles: true }))
    JS

    within ".event-calendars__import-preview-table-shell" do
      assert_text "Nov 20 • 11:00 AM – 11:45 AM"
      assert_text "Oct 1 • 11:00 AM – 11:45 AM"
      assert_text "Absolute time retained"
    end

    click_button "Review import"
    assert_selector "dialog[open]"

    within "dialog[open]" do
      assert_text "Nov 20 • 11:00 AM – 11:45 AM"
      assert_text "Oct 1 • 11:00 AM – 11:45 AM"
      assert_text "Absolute time retained"
      click_button "Cancel"
    end

    assert_no_selector "dialog[open]"
  end

  test "planner can select and deselect all source items from the source list" do
    login_as_planner
    visit event_calendar_item_import_path(@destination_event, source_event_id: @source_event.id, source_timeline_ref: "run_of_show")

    within ".event-calendars__import-source-table" do
      click_button "Select all"
    end

    within ".event-calendars__import-preview" do
      assert_text "3"
      assert_text "Ceremony"
      assert_text "Reception"
      assert_text "Afterparty"
    end

    within ".event-calendars__import-source-table" do
      click_button "Deselect all"
    end

    within ".event-calendars__import-preview" do
      assert_text "Select items to preview the projected import schedule."
    end
  end

  test "planner preview distinguishes fallback relative items from preserved relative links" do
    reception = calendar_items(:reception)

    login_as_planner
    visit event_calendar_item_import_path(@destination_event, source_event_id: @source_event.id, source_timeline_ref: "run_of_show")

    find("input##{ActionView::RecordIdentifier.dom_id(reception, :import_selection)}", visible: :all).set(true)

    within ".event-calendars__import-preview-table-shell" do
      assert_text "Reception"
      assert_text "Will convert to absolute time"
    end

    find("input##{ActionView::RecordIdentifier.dom_id(@ceremony, :import_selection)}", visible: :all).set(true)

    within ".event-calendars__import-preview-table-shell" do
      assert_text "Ceremony"
      assert_text "Reception"
      assert_text "Relative link preserved"
      assert_no_text "Will convert to absolute time"
    end
  end

  test "planner preview counts unscheduled absolute items as missing time" do
    unscheduled_item = event_calendars(:run_of_show).calendar_items.create!(
      title: "Unscheduled walkthrough",
      starts_at: nil,
      duration_minutes: 30,
      position: 11
    )

    login_as_planner
    visit event_calendar_item_import_path(@destination_event, source_event_id: @source_event.id, source_timeline_ref: "run_of_show")

    find("input##{ActionView::RecordIdentifier.dom_id(unscheduled_item, :import_selection)}", visible: :all).set(true)

    within ".event-calendars__import-preview" do
      assert_selector "[data-calendar-item-import-target='missingCount']", text: "1"
    end

    within ".event-calendars__import-preview-table-shell" do
      assert_text "DATE TBD"
      assert_text "Time TBD"
      assert_text "No computable start time"
    end
  end

  test "planner preview computes preserved relative times even when the anchor appears later in the list" do
    source_calendar = event_calendars(:run_of_show)
    late_anchor = source_calendar.calendar_items.create!(
      title: "Late anchor",
      starts_at: Time.utc(2025, 10, 1, 15, 0, 0),
      duration_minutes: 30,
      position: 20
    )
    early_relative = source_calendar.calendar_items.create!(
      title: "Early relative",
      relative_anchor: late_anchor,
      relative_offset_minutes: 15,
      duration_minutes: 20,
      position: 19
    )

    login_as_planner
    visit event_calendar_item_import_path(@destination_event, source_event_id: @source_event.id, source_timeline_ref: "run_of_show")

    find("input##{ActionView::RecordIdentifier.dom_id(early_relative, :import_selection)}", visible: :all).set(true)
    find("input##{ActionView::RecordIdentifier.dom_id(late_anchor, :import_selection)}", visible: :all).set(true)

    within ".event-calendars__import-preview-table-shell" do
      assert_text "Early relative"
      assert_text "Nov 15 • 11:15 AM – 11:35 AM"
      assert_text "Relative link preserved"
      assert_no_text "Time TBD"
    end
  end

  test "planner all-listed mode previews the filtered timeline and disables row checkboxes" do
    vendor_view = event_calendar_views(:vendor_view)

    login_as_planner
    visit event_calendar_item_import_path(@destination_event, source_event_id: @source_event.id, source_timeline_ref: "view:#{vendor_view.id}")

    choose "All listed items"

    assert_text "All 1 listed item will be imported."
    assert_selector "input[name='item_ids[]'][disabled]", count: 1, visible: :all

    within ".event-calendars__import-preview-table-shell" do
      assert_text "Reception"
      assert_no_text "Ceremony"
      assert_no_text "Afterparty"
    end
  end

  test "planner preview always shows midnight timestamps explicitly" do
    @destination_event.event_calendars.create!(name: "Run of Show", timezone: "UTC")
    midnight_item = event_calendars(:run_of_show).calendar_items.create!(
      title: "Midnight load-in",
      starts_at: Time.utc(2025, 10, 1, 0, 0, 0),
      duration_minutes: 30,
      position: 10
    )

    login_as_planner
    visit event_calendar_item_import_path(@destination_event, source_event_id: @source_event.id, source_timeline_ref: "run_of_show")

    find("input##{ActionView::RecordIdentifier.dom_id(midnight_item, :import_selection)}", visible: :all).set(true)

    within ".event-calendars__import-preview-table-shell" do
      assert_text "Oct 1 • 12:00 AM – 12:30 AM"
      assert_text "Nov 15 • 12:00 AM – 12:30 AM"
    end

    click_button "Review import"

    within "dialog[open]" do
      assert_text "Nov 15 • 12:00 AM – 12:30 AM"
    end
  end

  test "planner preview does not carry source time labels into imported projection" do
    labeled_item = event_calendars(:run_of_show).calendar_items.create!(
      title: "Labeled import item",
      starts_at: Time.utc(2025, 10, 1, 10, 0, 0),
      duration_minutes: 30,
      time_caption: "Contracts Month",
      position: 12
    )

    login_as_planner
    visit event_calendar_item_import_path(@destination_event, source_event_id: @source_event.id, source_timeline_ref: "run_of_show")

    find("input##{ActionView::RecordIdentifier.dom_id(labeled_item, :import_selection)}", visible: :all).set(true)

    within ".event-calendars__import-preview-table-shell" do
      assert_selector ".event-calendars__import-cell-meta", text: "Contracts Month", count: 1
    end
  end

  test "planner can confirm an import without batch tagging" do
    login_as_planner
    visit event_calendar_item_import_path(@destination_event, source_event_id: @source_event.id, source_timeline_ref: "run_of_show")

    find("input##{ActionView::RecordIdentifier.dom_id(@ceremony, :import_selection)}", visible: :all).set(true)
    click_button "Review import"

    within "dialog[open]" do
      assert_text "Not added"
      click_button "Confirm import"
    end

    assert_current_path event_calendar_path(@destination_event)
    assert_no_text "Tagged this import batch as"
    assert_empty @destination_event.run_of_show_calendar.calendar_items.find_by!(title: "Ceremony").event_calendar_tags.where("lower(name) LIKE ?", "imported%")
  end

  test "batch tagging is optional and off by default" do
    login_as_planner
    visit event_calendar_item_import_path(@destination_event, source_event_id: @source_event.id, source_timeline_ref: "run_of_show")

    assert_unchecked_field "batch_tag_enabled"
    assert_text "Expected batch tag:"
    assert_text "Not added"

    find("input##{ActionView::RecordIdentifier.dom_id(@ceremony, :import_selection)}", visible: :all).set(true)
    find("input[name='batch_tag_enabled']", visible: :all).set(true)

    assert_text "imported"

    click_button "Review import"

    within "dialog[open]" do
      assert_text "imported"
      click_button "Confirm import"
    end

    assert_current_path event_calendar_path(@destination_event)
    assert_text "Tagged this import batch as imported."
    assert_includes @destination_event.run_of_show_calendar.calendar_items.find_by!(title: "Ceremony").event_calendar_tags.pluck(:name), "imported"
  end

end
