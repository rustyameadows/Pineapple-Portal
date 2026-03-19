require "application_system_test_case"

class CalendarBulkEditTest < ApplicationSystemTestCase
  setup do
    @event = events(:one)
    @view = event_calendar_views(:vendor_view)
    @ceremony = calendar_items(:ceremony)
    @reception = calendar_items(:reception)
  end

  test "run of show bulk edit requires confirmation before applying vendor changes" do
    login_as_planner
    visit event_calendar_path(@event)

    assert_no_selector ".event-calendars__bulk-toolbar", visible: true

    find("input.event-calendars__bulk-checkbox[value='#{@ceremony.id}']").check

    assert_selector ".event-calendars__bulk-toolbar", visible: true
    assert_text "1 item(s) selected"

    select "Set vendor", from: "Action"
    fill_in "Vendor", with: "Golden Pine Events"

    click_button "Apply"
    assert_selector "dialog[open]"

    click_button "Cancel"
    assert_nil @ceremony.reload.vendor_name

    click_button "Apply"
    within "dialog[open]" do
      click_button "Confirm changes"
    end

    assert_current_path event_calendar_path(@event)
    assert_text "Vendor updated for 1 item."
    assert_equal "Golden Pine Events", @ceremony.reload.vendor_name
  end

  test "derived calendar bulk removal stays on the derived view and updates the filtered results" do
    login_as_planner
    visit event_calendar_view_path(@event, @view)

    assert_text "Reception"
    assert_no_text "Afterparty"

    find("input.event-calendars__bulk-checkbox[value='#{@reception.id}']").check
    select "Remove tags", from: "Action"
    find("select[name='bulk[tag_ids][]']").find("option", text: "Vendor").select_option

    click_button "Apply"
    within "dialog[open]" do
      click_button "Confirm changes"
    end

    assert_current_path event_calendar_view_path(@event, @view)
    assert_text "No items match this view yet."
    assert_not_includes @reception.reload.event_calendar_tag_ids, event_calendar_tags(:vendor).id
  end

  private

  def login_as_planner
    visit login_path
    fill_in "Email", with: users(:one).email
    fill_in "Password", with: "password123"
    click_button "Log In"
  end
end
