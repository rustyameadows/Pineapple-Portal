require "test_helper"

module Events
  class CalendarsControllerTest < ActionDispatch::IntegrationTest
    setup do
      @event = events(:one)
      log_in_as(users(:one))
    end

    test "shows calendars index" do
      get event_calendars_path(@event)

      assert_response :success
      assert_select "h1", text: "Timeline Views"
      assert_select "h2.calendar-card__title", text: /Run of Show/
    end

    test "shows run of show detail" do
      get event_calendar_path(@event)

      assert_response :success
      assert_select "table.event-table tbody tr", minimum: 1
    end
  end
end
