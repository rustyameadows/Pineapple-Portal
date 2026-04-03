require "application_system_test_case"

class CalendarAutocompleteTest < ApplicationSystemTestCase
  setup do
    @event = events(:one)
    @bulk_item = calendar_items(:ceremony)
    @edit_item = calendar_items(:decision_flowers)

    @keyboard_vendor_alpha = GlobalVendor.create!(name: "Keyboard Alpha Vendor")
    @keyboard_vendor_beta = GlobalVendor.create!(name: "Keyboard Beta Vendor")
    @pointer_venue = GlobalVenue.create!(name: "Pointer Select Venue")
  end

  test "bulk edit vendor autocomplete supports keyboard selection and escape closes the menu" do
    login_as_planner
    visit event_calendar_path(@event)

    find("input.event-calendars__bulk-checkbox[value='#{@bulk_item.id}']", visible: :all).set(true)
    find("select[name='bulk[bulk_action]']").select("Set vendor")

    within ".event-calendars__bulk-toolbar" do
      fill_in "Vendor", with: "Keyboard"

      assert_selector ".calendar-item-form__autocomplete-menu", visible: true
      assert_selector ".calendar-item-form__autocomplete-option", text: @keyboard_vendor_alpha.name
      assert_selector ".calendar-item-form__autocomplete-option", text: @keyboard_vendor_beta.name

      vendor_input = find_field("Vendor")
      vendor_input.send_keys(:escape)

      assert_no_selector ".calendar-item-form__autocomplete-menu", visible: true
      assert_equal "Keyboard", vendor_input.value

      fill_in "Vendor", with: ""
      fill_in "Vendor", with: "Keyboard"

      assert_selector ".calendar-item-form__autocomplete-option", text: @keyboard_vendor_alpha.name

      vendor_input = find_field("Vendor")
      vendor_input.send_keys(:arrow_down, :enter)

      assert_equal @keyboard_vendor_alpha.name, vendor_input.value
    end

    click_button "Apply"
    assert_selector "dialog[open]"

    within "dialog[open]" do
      click_button "Confirm changes"
    end

    assert_current_path event_calendar_path(@event)
    assert_text "Vendor updated for 1 item."
    assert_equal @keyboard_vendor_alpha.name, @bulk_item.reload.vendor_name
  end

  test "calendar item autocomplete fills from click and persists on save" do
    login_as_planner
    visit edit_event_calendar_item_path(@event, @edit_item)

    fill_in "Location", with: "Pointer"
    assert_selector ".calendar-item-form__autocomplete-menu", visible: true
    assert_selector ".calendar-item-form__autocomplete-option", text: @pointer_venue.name

    find(".calendar-item-form__autocomplete-option", text: @pointer_venue.name).click

    assert_equal @pointer_venue.name, find_field("Location").value

    find("input[type='submit']", visible: true).click

    assert_text "Calendar item updated."
    assert_current_path event_calendar_path(@event)
    assert_equal @pointer_venue.name, @edit_item.reload.location_name
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
