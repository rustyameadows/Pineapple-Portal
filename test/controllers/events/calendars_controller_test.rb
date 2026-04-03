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
      assert_select "a", text: "Import Items"
    end

    test "run of show timeline links return to the edited row anchor" do
      item = calendar_items(:ceremony)
      row_anchor = ActionView::RecordIdentifier.dom_id(item, :timeline_row)
      return_to = "#{event_calendar_path(@event)}##{row_anchor}"
      expected_href = edit_event_calendar_item_path(@event, item, return_to: return_to)

      get event_calendar_path(@event)

      assert_response :success
      assert_select "a.event-calendars__title-link[href='#{expected_href}']", text: item.title, count: 1
      assert_select "a.event-calendars__edit-link[href='#{expected_href}']", text: "Edit", count: 1
    end
  end
end
