require "test_helper"

module Events
  class CalendarViewsControllerTest < ActionDispatch::IntegrationTest
    setup do
      log_in_as(users(:one))
      @event = events(:one)
      @decision_view = event_calendar_views(:decision_view)
      @non_decision_view = event_calendar_views(:vendor_view)
    end

    test "decision view shows decision-specific ctas and status column first" do
      get event_calendar_view_url(@event, @decision_view)

      assert_response :success
      expected_add_item_path = new_event_calendar_item_path(
        @event,
        return_to: event_calendar_view_path(@event, @decision_view),
        default_tag_name: "Decisions"
      )
      assert_select "a[href='#{expected_add_item_path}']", text: "Add Item"
      assert_select "a[href='#{client_event_calendar_path(@event.portal_slug.presence || @event.id, 'decision-calendar')}']", text: "View in Portal"
      assert_select "table.event-calendars__table thead tr th:first-child", text: "Status"
    end

    test "decision view hides portal cta when not client visible" do
      @decision_view.update!(client_visible: false)

      get event_calendar_view_url(@event, @decision_view)

      assert_response :success
      assert_select "a", text: "View in Portal", count: 0
      assert_select "p.event-section__note", text: /Set this timeline to visible in client portal/
    end

    test "non-decision view keeps shared table and does not show decision ctas" do
      get event_calendar_view_url(@event, @non_decision_view)

      assert_response :success
      assert_select "a", text: "Add Item", count: 0
      assert_select "a", text: "View in Portal", count: 0
      assert_select "table.event-calendars__table thead tr th:first-child", text: "Schedule"
    end

    test "decision view uses month year segment labels when no caption exists" do
      get event_calendar_view_url(@event, @decision_view)

      assert_response :success
      assert_select ".event-calendars__date-label", text: "September 2025", minimum: 1
    end

    test "decision view segment label uses caption when present" do
      calendar_items(:decision_flowers).update!(time_caption: "Contracts Month")

      get event_calendar_view_url(@event, @decision_view)

      assert_response :success
      assert_select ".event-calendars__date-label", text: "Contracts Month", minimum: 1
    end
  end
end
