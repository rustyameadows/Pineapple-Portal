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

    test "shows run of show timeline search and bulk selection controls" do
      get event_calendar_path(@event)

      assert_response :success
      assert_select "input[aria-label='Search timeline']", count: 1
      assert_select "button", text: "Clear search/filters", count: 1
      assert_select ".event-calendars__filter-summary-label", text: "Tags", count: 1
      assert_match(/Select all \d+ item(s)?/, response.body)
      assert_includes response.body, "Deselect all"
      assert_select ".event-calendars__filter-menu label", text: "None", minimum: 4
    end

    test "shows timing conversion actions for selected run of show rows" do
      get event_calendar_path(@event)

      assert_response :success
      assert_select "button[data-calendar-bulk-edit-target='relativeTimingButton']", text: "Change relative timing", count: 1
      assert_select "button[data-calendar-bulk-edit-target='absoluteTimingButton']", text: "Make absolute", count: 1
      assert_select "form[action='#{event_calendar_timing_conversion_path(@event)}'][method='post']", count: 1
      assert_select "tr[data-calendar-item-id][data-calendar-item-title][data-calendar-item-start-at]", minimum: 1
    end

    test "run of show timeline links preserve filtered return_to and row anchor" do
      item = calendar_items(:ceremony)
      row_anchor = ActionView::RecordIdentifier.dom_id(item, :timeline_row)
      filtered_path = event_calendar_path(
        @event,
        q: "Ceremony",
        vendors: [ "vendor" ],
        locations: [ "grand-ballroom" ],
        teams: [ "ada-fixture" ],
        tags: [ "day-of" ]
      )
      return_to = "#{filtered_path}##{row_anchor}"
      expected_href = edit_event_calendar_item_path(@event, item, return_to: return_to)

      get filtered_path

      assert_response :success
      assert_select "a.event-calendars__title-link[href='#{expected_href}']", text: item.title, count: 1
      assert_select "a.event-calendars__edit-link[href='#{expected_href}']", text: "Edit", count: 1
    end
  end
end
