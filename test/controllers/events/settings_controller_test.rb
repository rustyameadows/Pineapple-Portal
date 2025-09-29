require "test_helper"

module Events
  class SettingsControllerTest < ActionDispatch::IntegrationTest
    setup do
      @event = events(:one)
      log_in_as(users(:two))
    end

    test "displays unified people rollup" do
      get event_settings_url(@event)

      assert_response :success
      assert_select ".event-settings__people-card-name", text: "Maria Cater"
      assert_select ".event-settings__people-card-source", text: "Sunshine Catering"
      assert_select ".event-settings__people-card-name", text: "Venue Manager"
      assert_select ".event-settings__people-card-eyebrow", text: "Planner"
      assert_select ".event-settings__badge--internal", text: "Internal only"
    end
  end
end
