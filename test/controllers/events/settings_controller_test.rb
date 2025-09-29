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
    end

    test "renders clients page" do
      get clients_event_settings_url(@event)
      assert_response :success
      assert_select "h1", text: "Client Access"
    end

    test "renders client portal page" do
      get client_portal_event_settings_url(@event)
      assert_response :success
      assert_select "h1", text: "Quick Links"
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
