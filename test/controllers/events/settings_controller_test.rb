require "test_helper"

module Events
  class SettingsControllerTest < ActionDispatch::IntegrationTest
    setup do
      @event = events(:one)
      log_in_as(users(:two))
    end

    test "renders general settings page" do
      get event_settings_url(@event)

      assert_response :success
      assert_select "h1", text: @event.name
      assert_select "p", text: "Keep the basics fresh so the client portal stays on message.", count: 0
      assert_select "input[name='event[portal_slug]']", count: 0
      assert_select "input[name='event[guest_count]'][value='175']", count: 1
      assert_select "input[name='event[attire]'][value='Black Tie']", count: 1
      assert_select "input[name='event[style]'][value='Elegant Garden']", count: 1
      assert_select "input[name='event[color_palette]'][value='Ivory, Sage, Gold']", count: 1
      assert_select "[data-controller='generated-markdown-editor']", count: 3
      assert_select "[data-generated-markdown-editor-target='openButton']", count: 3
      assert_select "button[data-markdown-format='bold']", count: 6
      assert_select "button[data-markdown-format='italic']", count: 6
      assert_select "button[data-markdown-format='link']", count: 6
      assert_select "button[data-markdown-format='headline']", count: 6
      assert_select "textarea[name='event[social_media_policy]'][data-generated-markdown-editor-target='source']", text: "Please do not post photos before the planner's announcement."
      assert_select "textarea[name='event[parking_details]'][data-generated-markdown-editor-target='source']", text: "Valet parking is available at the east entrance."
      assert_select "textarea[name='event[getting_ready_details]'][data-generated-markdown-editor-target='source']", text: "Bridal party should arrive by 8:00 AM and check in at suite 402."
      assert_select ".event-settings__hint", text: /Supports Markdown for bold, italic, links, and one headline style\./, count: 3
    end

    test "renders clients page" do
      get clients_event_settings_url(@event)
      assert_response :success
      assert_select "h1", text: "Client Access"
      assert_select "input[value='#{client_login_url}'][readonly]", count: 1
      assert_select "th", text: "Access"
      assert_select "th", text: "Portal Access", count: 0
      assert_select "th", text: "Financial Access", count: 0
      assert_select ".button.button--small", text: "Revoke Portal Access"
      assert_select ".button.button--small.button--ghost", text: "Grant Financial Access"
      assert_select ".button.button--small.button--ghost", text: "Generate Reset Link"
      assert_select "td.event-table__actions", text: /Generate Reset Link/, count: 0
      assert_select ".button.button--small.button--ghost", text: "Edit"
      assert_select ".button.button--small.button--danger", text: "Remove"
    end

    test "renders client portal page" do
      get client_portal_event_settings_url(@event)
      assert_response :success
      assert_select "h1", text: "Portal URL"
      assert_select "h1", text: "Planning Links"
      assert_select "h1", text: "Quick Links"
      assert_select "h2", text: "Planner links in portal"
      assert_select "h2", text: "Hidden planner links", count: 0
      assert_select "input[name='event[portal_slug]']", count: 1
    end

    test "renders planners page" do
      get planners_event_settings_url(@event)
      assert_response :success
      assert_select "h1", text: "Planning Team"
    end

    test "renders vendors page" do
      generic_vendor_count = Vendors::PlanningCompany.excluding(@event.event_vendors).count
      available_global_vendor = GlobalVendor.create!(
        name: "Picker Floral Studio",
        default_vendor_type: "Floral",
        default_social_handle: "@pickerfloral",
        contacts_attributes: { "0" => { name: "Fern Picker", email: "fern@picker.test" } }
      )
      @event.update!(pineapple_team_meals: "**Eight planner meals** at 5:00 PM.")
      event_vendors(:catering).update!(team_meals: "**Three vendor meals** at 6:00 PM.")
      unselected_contact = global_vendors(:sunshine_catering).contacts.create!(
        name: "Unselected Roster Contact",
        email: "unselected@example.test"
      )

      get vendors_event_settings_url(@event)

      assert_response :success
      assert_select "h1", text: "Vendors"
      assert_select "table[data-vendor-roster][aria-label='Vendors and selected contacts for this event']", count: 1 do
        assert_select "th[scope='col']", text: "Vendor"
        assert_select "th[scope='col']", text: "Edit"
        assert_select "th[scope='col']", count: 2
        assert_select "tr[data-vendor-row][data-event-vendor-id]", count: @event.event_vendors.count
        assert_select "tr[data-vendor-contact-row]", count: 4
        assert_select "tr[data-vendor-contact-row]", text: /Maria Cater/, count: 1
        assert_select "tr[data-vendor-contact-row]", text: /Leo Light/, count: 1
        assert_select "tr[data-vendor-contact-row]", text: /Ada Fixture/, count: 1
        assert_select "tr[data-vendor-contact-row]", text: /Grace Fixture/, count: 1
        assert_select "tr[data-vendor-contact-row]", text: /#{Regexp.escape(unselected_contact.name)}/, count: 0
        assert_select "tr[data-vendor-meals-row]", count: 2
        assert_select "tr[data-event-vendor-id='#{event_vendors(:pineapple_one).id}'] + tr[data-vendor-meals-row][data-parent-event-vendor-id='#{event_vendors(:pineapple_one).id}']", count: 1
        assert_select "tr[data-event-vendor-id='#{event_vendors(:catering).id}'] + tr[data-vendor-meals-row][data-parent-event-vendor-id='#{event_vendors(:catering).id}']", count: 1
        assert_select ".event-settings__badge", text: "Hidden", count: 1
        assert_select ".event-settings__badge", text: "Client visible", count: 0
        assert_select ".event-settings__badge", text: "Planning company", count: 0
        assert_select ".event-settings__vendor-roster-meals", text: /Eight planner meals at 5:00 PM\./, count: 1
        assert_select ".event-settings__vendor-roster-meals", text: /Three vendor meals at 6:00 PM\./, count: 1
        assert_select ".event-settings__vendor-roster-meals", text: /\*\*/, count: 0
      end
      assert_select "button[aria-haspopup='dialog'][aria-controls]", count: @event.event_vendors.count + 1
      assert_select "dialog.event-settings__vendor-dialog[aria-labelledby]", count: @event.event_vendors.count + 1
      assert_select "textarea[name='event[pineapple_team_meals]']", count: 1
      assert_select "textarea[name='event_vendor[team_meals]']", count: generic_vendor_count
      assert_select "[data-controller='generated-markdown-editor']", count: 0
      assert_select "input[name*='contacts_attributes']", count: 0
      assert_select "textarea[name*='contacts_attributes']", count: 0
      assert_select "dialog.event-settings__vendor-dialog--association", count: generic_vendor_count
      assert_select "dialog.event-settings__vendor-dialog--association .event-settings__vendor-dialog-header-meta", text: /Settings for this event/, count: generic_vendor_count
      assert_select "dialog.event-settings__vendor-dialog--association .event-settings__vendor-dialog-section-title", text: "Event details", count: generic_vendor_count
      assert_select "dialog.event-settings__vendor-dialog--association .event-settings__vendor-dialog-section-title", text: "Meal notes", count: generic_vendor_count
      assert_select "dialog.event-settings__vendor-dialog--association .event-settings__vendor-dialog-section-title", text: "Contacts for this event", count: generic_vendor_count
      assert_select "a", text: "Manage vendor contacts", count: generic_vendor_count
      assert_select "input[type='checkbox'][name='event_vendor[global_vendor_contact_ids][]']", count: 3
      assert_select "input[type='checkbox'][name='event_vendor[global_vendor_contact_ids][]'][checked='checked']", count: 2
      assert_select ".event-settings__vendor-dialog-contact-item", text: /#{Regexp.escape(unselected_contact.name)}/, count: 1
      assert_select "input[name='event_vendor[name]']", count: 0
      assert_select "input[name='event_vendor[social_handle]']", count: 0
      assert_select "input[type='search'][data-vendor-picker-target='query']", count: 1
      assert_select "input[type='radio'][name='event_vendor[global_vendor_id]'][value='#{available_global_vendor.id}']", count: 1
      assert_select "tr[data-global-vendor-id='#{available_global_vendor.id}']", text: /Picker Floral Studio/, count: 1
      assert_select "button[name='event_vendor[create_global_vendor]']", count: 0
      assert_select "a[href='#{new_settings_global_vendor_path}']", text: "Create new vendor", count: 1
    end

    test "renders the special planning company block without a duplicate generic vendor form" do
      planning_event_vendor = event_vendors(:pineapple_one)
      planning_event_vendor.update!(team_meals: "This generic meal field should stay hidden.")
      planning_event_vendor.global_vendor.update!(name: "Pineapple Planning Company")
      planning_event_vendor.global_vendor.contacts.create!(name: "Hidden Global Planning Contact")

      get vendors_event_settings_url(@event)

      assert_response :success
      assert_select "tr.event-settings__vendor-roster-row--planning[data-event-vendor-id='#{planning_event_vendor.id}']",
                    text: /Pineapple Planning Company/, count: 1
      assert_select "tr.event-settings__vendor-roster-row--vendor", text: /Pineapple Planning Company/, count: 0
      assert_select "form[action='#{event_event_vendor_path(@event, planning_event_vendor)}']", count: 0
      assert_select "tr[data-parent-event-vendor-id='#{planning_event_vendor.id}']", count: 2
      assert_select "dialog#event-vendor-planning-dialog" do
        assert_select "h3", text: "Pineapple Planning Company"
        assert_select ".event-settings__vendor-dialog-header-meta", text: /Settings for this event/
        assert_select ".event-settings__vendor-dialog-section-title", text: "Meal notes"
        assert_select ".event-settings__vendor-dialog-section-title", text: "Event planners"
        assert_select "textarea[name='event[pineapple_team_meals]']", count: 1
        assert_select "input[name^='event_vendor']", count: 0
        assert_select "a", text: "Manage event planners", count: 1
        assert_select ".event-settings__vendor-dialog-contact-item", text: /Ada Fixture/, count: 1
        assert_select ".event-settings__vendor-dialog-contact-item", text: /Grace Fixture/, count: 1
      end
      assert_select "textarea[name='event[pineapple_team_meals]']", count: 1
      assert_no_match(/This generic meal field should stay hidden/, response.body)
      assert_no_match(/Hidden Global Planning Contact/, response.body)
    end

    test "renders locations page" do
      get locations_event_settings_url(@event)
      assert_response :success
      assert_select "h1", text: "Locations"
      assert_select "textarea[name='event_venue[address]']", count: @event.event_venues.count + 1
    end

    test "planner sees planners page without team management controls" do
      delete logout_url
      log_in_as(users(:one))

      get planners_event_settings_url(@event)

      assert_response :success
      assert_select "h1", text: "Planning Team"
      assert_select "a[href*='#{users_path}']", count: 0
      assert_select "input[name='event_team_member[lead_planner]']", count: 0
      assert_select "input[name='event_team_member[position]']", count: 0
      assert_select "form[action='#{event_team_members_path(@event)}']", count: 0
      assert_select "button", text: "Remove", count: 0
    end

    test "planner sees clients page without access management controls" do
      delete logout_url
      log_in_as(users(:one))

      get clients_event_settings_url(@event)

      assert_response :success
      assert_select "h1", text: "Client Access"
      assert_select "button", text: "Revoke Portal Access", count: 0
      assert_select "button", text: "Generate Reset Link", count: 0
      assert_select "a", text: "Edit", count: 0
      assert_select "button", text: "Remove", count: 0
      assert_select "form[action='#{event_team_members_path(@event)}']", count: 0
    end
  end
end
