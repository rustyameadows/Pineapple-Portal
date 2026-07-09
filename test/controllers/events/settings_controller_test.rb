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
      get vendors_event_settings_url(@event)
      assert_response :success
      assert_select "h1", text: "Vendors"
      assert_select "h3", text: "Pineapple Productions"
      assert_select "textarea[name='event[pineapple_team_meals]'][data-generated-markdown-editor-target='source']", count: 1
      assert_select "textarea[name='event_vendor[team_meals]'][data-generated-markdown-editor-target='source']", count: @event.event_vendors.count + 1
      assert_select "button[data-markdown-format='bold']", count: (@event.event_vendors.count + 2) * 2
      assert_select "button[data-markdown-format='italic']", count: (@event.event_vendors.count + 2) * 2
      assert_select "button[data-markdown-format='link']", count: (@event.event_vendors.count + 2) * 2
      assert_select "button[data-markdown-format='headline']", count: 0
      assert_select ".event-settings__hint", text: /Supports Markdown for bold, italic, and links\./, count: @event.event_vendors.count + 2
      assert_select "input[name*='contacts_attributes']", count: 0
      assert_select "textarea[name*='contacts_attributes']", count: 0
      assert_select ".event-settings__vendor-contact-heading", count: @event.event_vendors.count
      assert_select ".event-settings__hint", text: /Contacts are inherited from the global vendor and are read-only for this event\./, count: @event.event_vendors.count
      assert_select ".event-settings__contact-title", text: "Maria Cater", count: 1
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
