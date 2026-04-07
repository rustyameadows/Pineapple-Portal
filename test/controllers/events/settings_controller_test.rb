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
    end

    test "renders locations page" do
      get locations_event_settings_url(@event)
      assert_response :success
      assert_select "h1", text: "Locations"
    end
  end
end
