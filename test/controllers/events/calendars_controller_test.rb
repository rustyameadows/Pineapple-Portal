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
      assert_select "h2.calendar-card__title", text: /Run of Show/, count: 0
      assert_select ".calendar-card__badge", text: "Run of Show", count: 0
      assert_select "section.event-section.event-calendars__timezone-settings", count: 1
      assert_select "form.event-calendars__timezone-form[action='#{event_calendar_path(@event)}']", count: 1 do
        assert_select "input[name='return_to'][value='#{event_calendars_path(@event)}']", count: 1
        assert_select "select[name='event_calendar[timezone]']", count: 1
        assert_select "input[type='submit'][value='Save Timezone']", count: 1
      end
    end

    test "timezone update can return to timeline settings" do
      patch event_calendar_path(@event), params: {
        return_to: event_calendars_path(@event),
        event_calendar: {
          timezone: "America/New_York"
        }
      }

      assert_redirected_to event_calendars_path(@event)
      assert_equal "America/New_York", @event.run_of_show_calendar.reload.timezone
    end

    test "shows run of show detail" do
      get event_calendar_path(@event)

      assert_response :success
      assert_select "table.event-table tbody tr", minimum: 1
      assert_select "a", text: "Agent Assist"
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
      assert_select "form[action='#{event_calendar_timing_conversion_path(@event)}'][method='post'][data-turbo='false']", count: 1
      assert_select "button[data-calendar-bulk-edit-target='relativeTimingOption']", count: 2
      assert_select "button[data-calendar-bulk-edit-target='relativeAnchorPointOption']", count: 2
      assert_select "select[data-calendar-bulk-edit-target='relativeAnchorPointSelect']", count: 0
      assert_select "select[data-calendar-bulk-edit-target='relativeTargetSelect']", count: 0
      assert_select "select[data-calendar-bulk-edit-target='relativeAnchorSelect']", count: 0
      assert_no_match "Move item", response.body
      assert_no_match "Anchor item", response.body
      assert_no_match "Swap", response.body
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
