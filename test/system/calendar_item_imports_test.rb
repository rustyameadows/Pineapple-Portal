require "application_system_test_case"

class CalendarItemImportsTest < ApplicationSystemTestCase
  setup do
    @destination_event = events(:two)
    @source_event = events(:one)
    @ceremony = calendar_items(:ceremony)
  end

  test "planner preview updates when the anchor date changes and the dialog mirrors the projection" do
    login_as_planner
    visit event_calendar_item_import_path(@destination_event, source_event_id: @source_event.id, source_timeline_ref: "run_of_show")

    assert_equal @destination_event.starts_on.to_s, find_field("Anchor date").value

    find("input##{ActionView::RecordIdentifier.dom_id(@ceremony, :import_selection)}", visible: :all).set(true)

    within ".event-calendars__import-preview-table-shell" do
      assert_text "Ceremony"
      assert_text "Nov 15 • 10:00 AM – 10:45 AM"
    end

    page.execute_script(<<~JS)
      const input = document.querySelector("input[name='anchor_date']")
      input.value = "2025-11-20"
      input.dispatchEvent(new Event("input", { bubbles: true }))
      input.dispatchEvent(new Event("change", { bubbles: true }))
    JS

    within ".event-calendars__import-preview-table-shell" do
      assert_text "Nov 20 • 10:00 AM – 10:45 AM"
      assert_text "Oct 1 • 11:00 AM – 11:45 AM"
      assert_text "Absolute time retained"
    end

    click_button "Review import"
    assert_selector "dialog[open]"

    within "dialog[open]" do
      assert_text "Nov 20 • 10:00 AM – 10:45 AM"
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

  private

  def login_as_planner
    visit login_path
    fill_in "Email", with: users(:one).email
    fill_in "Password", with: "password123"
    click_button "Log In"
    assert_text "Your Active Events"
  end
end
