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

    test "derived timeline shows shared search filters and master option lists" do
      get event_calendar_view_url(@event, @non_decision_view)

      assert_response :success
      assert_select "input[aria-label='Search timeline']", count: 1
      assert_select "button", text: "Clear search/filters", count: 1
      assert_select ".event-calendars__filter-summary-label", text: "Tags", count: 1
      assert_match(/Select all \d+ item(s)?/, response.body)
      assert_includes response.body, "Grand Ballroom"
      assert_includes response.body, "Ada Fixture"
      assert_includes response.body, "Temp Contractor"
      assert_select ".event-calendars__filter-menu label", text: "None", minimum: 4
    end

    test "derived timeline links preserve filtered return_to and row anchor" do
      item = calendar_items(:reception)
      row_anchor = ActionView::RecordIdentifier.dom_id(item, :timeline_row)
      filtered_path = event_calendar_view_path(
        @event,
        @non_decision_view,
        q: "Reception",
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
