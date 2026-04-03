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
