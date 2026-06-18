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

    test "edit renders derived view controls as selectable cards and tag pills" do
      get edit_event_calendar_view_url(@event, @non_decision_view)

      assert_response :success
      assert_select "form.calendar-view-form", count: 1
      assert_select "p.event-section__subtitle", count: 0
      assert_select ".calendar-view-form__eyebrow", text: "View Details", count: 0
      assert_select "input[name='event_calendar_view[name]']", count: 1
      assert_select "input[name='event_calendar_view[slug]']", count: 0
      assert_select "input[name='event_calendar_view[hide_locked]']", count: 0
      assert_select "textarea[name='event_calendar_view[description]']", count: 0
      assert_select ".calendar-view-form__choice-card input[type='radio'][value='day'][checked='checked']", count: 1
      assert_select ".calendar-item-form__pill.calendar-item-form__pill--tag", text: "Vendor", count: 1
      assert_select ".calendar-item-form__pill.calendar-item-form__pill--tag input[type='checkbox'][checked='checked']", minimum: 1
      assert_select ".calendar-view-form__actions .calendar-item-form__actions-left button[form]", text: "Delete Derived Calendar", count: 1
      assert_select ".calendar-view-form__actions .calendar-item-form__actions-right a", text: "Cancel", count: 1
      assert_select ".calendar-view-form__actions .calendar-item-form__actions-right input[type='submit']", count: 1
      assert_select ".calendar-view-form__danger-zone", count: 0
      assert_select ".event-form__group--checkbox", count: 0
    end

    test "new derived view form starts with name field after page title" do
      get new_event_calendar_view_url(@event)

      assert_response :success
      assert_select "p.event-section__subtitle", count: 0
      assert_select ".calendar-view-form__eyebrow", text: "View Details", count: 0
      assert_select "input[name='event_calendar_view[name]']", count: 1
    end

    test "decision view uses monthly segments and shows item day in schedule column" do
      get event_calendar_view_url(@event, @decision_view)

      assert_response :success
      assert_select ".event-calendars__date-label", text: "September 2025", count: 1
      assert_select "td.event-calendars__schedule-column", text: "Sep 15", minimum: 1
      assert_select "td.event-calendars__schedule-column", text: /12:00 PM/, count: 0
    end

    test "monthly decision view ignores time captions for segment labels" do
      calendar_items(:decision_flowers).update!(time_caption: "Contracts Month")

      get event_calendar_view_url(@event, @decision_view)

      assert_response :success
      assert_select ".event-calendars__date-label", text: "Contracts Month", count: 0
      assert_select ".event-calendars__date-label", text: "September 2025", count: 1
    end

    test "view settings can switch segment granularity" do
      patch event_calendar_view_url(@event, @non_decision_view), params: {
        event_calendar_view: {
          name: @non_decision_view.name,
          slug: @non_decision_view.slug,
          description: @non_decision_view.description,
          segment_granularity: EventCalendarView::SEGMENT_GRANULARITIES[:month],
          tag_filter: @non_decision_view.tag_filter
        }
      }

      assert_redirected_to event_calendar_view_path(@event, @non_decision_view)
      assert @non_decision_view.reload.monthly_segments?
    end
  end
end
