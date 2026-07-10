require "application_system_test_case"

class VendorRosterTest < ApplicationSystemTestCase
  setup do
    @event = events(:one)
    @vendor = event_vendors(:catering)
    @available_global_vendor = GlobalVendor.create!(
      name: "Picker Floral Studio",
      default_vendor_type: "Floral",
      default_social_handle: "@pickerfloral"
    )
    @event.update!(pineapple_team_meals: "**Eight planner meals** at 5:00 PM.")
    @vendor.update!(team_meals: "**Three vendor meals** at 6:00 PM.")
  end

  test "planner reviews the dense roster and uses the vendor dialogs" do
    login_as_planner
    visit vendors_event_settings_path(@event)

    assert_selector "table[data-vendor-roster]"
    assert_selector "tr[data-vendor-row][data-event-vendor-id='#{@vendor.id}']",
                    text: /#{Regexp.escape(@vendor.global_vendor.name)}/i
    assert_selector "tr[data-vendor-meals-row][data-parent-event-vendor-id='#{@vendor.id}']",
                    text: /Three vendor meals at 6:00 PM\./
    assert_selector "tr[data-vendor-contact-row][data-parent-event-vendor-id='#{@vendor.id}']", text: "Maria Cater"

    within "tr[data-vendor-row][data-event-vendor-id='#{@vendor.id}']" do
      click_button "Edit"
    end

    dialog_id = "event-vendor-#{@vendor.id}-dialog"
    assert_selector "dialog##{dialog_id}[open]"
    within "dialog##{dialog_id}" do
      assert_text "Settings for this event"
      assert_selector ".event-settings__vendor-dialog-section-title", text: "Event details"
      assert_selector ".event-settings__vendor-dialog-section-title", text: "Meal notes"
      assert_selector ".event-settings__vendor-dialog-section-title", text: "Contacts for this event"
      assert_field "Vendor services", with: @vendor.vendor_type
      assert_field "Meal notes"
      assert_text(/Contacts for this event/i)
      assert_checked_field "Maria Cater"
      click_button "Cancel"
    end
    assert_no_selector "dialog##{dialog_id}[open]"
    assert_equal dialog_id, page.evaluate_script("document.activeElement.getAttribute('aria-controls')")

    click_button "Add Vendor"
    assert_selector "dialog#event-vendor-new-dialog[open]"
    within "dialog#event-vendor-new-dialog" do
      assert_field "Search global vendors"
      assert_button "Add selected vendor", disabled: true
      fill_in "Search global vendors", with: "Picker Floral"
      assert_selector "tr[data-global-vendor-id='#{@available_global_vendor.id}']", visible: true
      find("#event_vendor_global_vendor_id_#{@available_global_vendor.id}", visible: :all).choose
      assert_button "Add selected vendor", disabled: false
      click_button "Cancel"
    end

    planning_vendor = event_vendors(:pineapple_one)
    within "tr[data-vendor-row][data-event-vendor-id='#{planning_vendor.id}']" do
      click_button "Edit"
    end
    assert_selector "dialog#event-vendor-planning-dialog[open]"
    within "dialog#event-vendor-planning-dialog" do
      assert_field "Pineapple meal notes"
      assert_selector "h4", text: /Event planners/i
      assert_link "Manage event planners"
      assert_no_field "Vendor services"
      click_button "Cancel"
    end
  end

  test "roster and dialog stay within a narrow viewport" do
    page.current_window.resize_to(640, 800)
    login_as_planner
    visit vendors_event_settings_path(@event)

    viewport = page.evaluate_script(<<~JS)
      ({
        bodyWidth: document.documentElement.scrollWidth,
        viewportWidth: document.documentElement.clientWidth,
        layoutColumns: getComputedStyle(document.querySelector('.event-layout')).gridTemplateColumns,
        layoutClass: document.querySelector('.event-layout').className,
        shellWidth: document.querySelector('.event-settings__vendor-roster-shell').getBoundingClientRect().width,
        rosterScrolls: document.querySelector('.event-settings__vendor-roster-shell').scrollWidth >
          document.querySelector('.event-settings__vendor-roster-shell').clientWidth
      })
    JS

    assert_operator viewport.fetch("bodyWidth"), :<=, viewport.fetch("viewportWidth") + 1, viewport.inspect
    assert_not viewport.fetch("rosterScrolls"), viewport.inspect

    click_button "Add Vendor"
    dialog_width = page.evaluate_script("document.querySelector('#event-vendor-new-dialog').getBoundingClientRect().width")
    assert_operator dialog_width, :<=, viewport.fetch("viewportWidth") - 16
  end
end
