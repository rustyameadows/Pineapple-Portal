require "test_helper"

class DecisionsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:two)
    @event = events(:one)
    @calendar = event_calendars(:run_of_show)
    @decision_tag = @calendar.event_calendar_tags.create!(name: "Decisions")
    @decision_items = [
      calendar_items(:decision_flowers),
      calendar_items(:decision_catering)
    ]
    @decision_items.each { |item| item.event_calendar_tags << @decision_tag }
  end

  test "requires planner login" do
    get decisions_url

    assert_redirected_to login_url
  end

  test "renders master decisions from active events only" do
    log_in_as(@user)
    non_decision = calendar_items(:ceremony)
    archived_item = create_decision_item_for_event!(
      event: create_event!(name: "Archived Gala", archived_at: 1.day.ago),
      title: "Archived Decision",
      starts_at: Time.zone.local(2025, 9, 18, 12, 0)
    )

    get decisions_url

    assert_response :success
    assert_select "h1", text: "Decisions"
    assert_select "p.event-section__lead", text: "Decision items across active events."
    assert_match(/Events.*Decisions.*Vendors/m, response.body)
    assert_select "a[href='#{decisions_path}']", text: "Decisions", count: 1
    assert_select ".event-calendars__date-label", text: "September 2025", count: 1
    assert_select "table.event-calendars__table.event-calendars__table--master-decisions", count: 1
    assert_select "table.event-calendars__table thead tr th:nth-child(1)", text: "Schedule"
    assert_select "table.event-calendars__table thead tr th:nth-child(2)", text: "Status"
    assert_select "table.event-calendars__table thead tr th:nth-child(3)", text: "Event"
    assert_select "table.event-calendars__table thead tr th:nth-child(4)", text: "Title"
    assert_select "table.event-calendars__table thead tr th:nth-child(5)", text: "Vendor"
    assert_select "table.event-calendars__table thead tr th", text: "Location", count: 0
    assert_select "table.event-calendars__table thead tr th", text: "Team", count: 0
    assert_select "td.event-calendars__event-column", text: @event.name, minimum: 1
    assert_select "td.event-calendars__schedule-column", text: "Sep 15", minimum: 1
    assert_select "td.event-calendars__schedule-column", text: /12:00 PM/, count: 0
    assert_select "a.event-calendars__title-link", text: @decision_items.first.title, count: 1
    assert_select "a.event-calendars__title-link", text: @decision_items.second.title, count: 1
    assert_select "a.event-calendars__title-link", text: non_decision.title, count: 0
    assert_select "a.event-calendars__title-link", text: archived_item.title, count: 0
    assert_select ".event-calendars__date-row td[colspan='7']", count: 1
  end

  test "renders master decision bulk selection filters edit links and event links" do
    log_in_as(@user)
    item = @decision_items.first
    view = event_calendar_views(:decision_view)
    row_anchor = ActionView::RecordIdentifier.dom_id(item, :timeline_row)
    edit_href = edit_event_calendar_item_path(@event, item, return_to: "#{decisions_path}##{row_anchor}")

    get decisions_url

    assert_response :success
    assert_select "section[data-controller~='calendar-bulk-edit']", count: 1
    assert_select "input[aria-label='Search timeline']", count: 1
    assert_select ".event-calendars__filter-summary-label", text: "Event", count: 1
    assert_select ".event-calendars__filter-summary-label", text: "Status", count: 1
    assert_select ".event-calendars__filter-summary-label", text: "Vendor", count: 0
    assert_select ".event-calendars__filter-summary-label", text: "Location", count: 0
    assert_select ".event-calendars__filter-summary-label", text: "Team", count: 0
    assert_select ".event-calendars__filter-summary-label", text: "Tags", count: 0
    assert_select "form#master-decisions-bulk-form[action='#{decisions_bulk_update_path}']", count: 1
    assert_select "table.event-calendars__table thead tr th:last-child", text: "Select"
    assert_select ".event-calendars__date-actions button", text: "Select", minimum: 1
    assert_select ".event-calendars__date-actions button", text: "Deselect", minimum: 1
    assert_select "button", text: "Mark as Planned", count: 1
    assert_select "button", text: "Mark as In Progress", count: 1
    assert_select "button", text: "Mark as Completed", count: 1
    assert_select "td.event-calendars__event-column a[href='#{event_path(@event)}']", text: @event.name, minimum: 1
    assert_select "a.event-calendars__title-link[href]", text: item.title, count: 1 do |links|
      assert_includes links.first["href"], event_calendar_view_path(@event, view)
    end
    assert_select "a.event-calendars__edit-link[href='#{edit_href}']", text: "Edit", count: 1
  end

  test "links decision rows to the event decision calendar view" do
    log_in_as(@user)
    view = event_calendar_views(:decision_view)
    item = @decision_items.first
    expected_href = "#{event_calendar_view_path(@event, view)}##{ActionView::RecordIdentifier.dom_id(item, :timeline_row)}"

    get decisions_url

    assert_response :success
    assert_select "a.event-calendars__title-link[href='#{expected_href}']", text: item.title, count: 1
  end

  test "bulk status update changes selected decisions across active events" do
    log_in_as(@user)
    other_event = create_event!(name: "Second Wedding")
    other_item = create_decision_item_for_event!(
      event: other_event,
      title: "Confirm Rentals",
      starts_at: Time.zone.local(2025, 9, 21, 9, 0)
    )

    patch decisions_bulk_update_url, params: {
      item_ids: [@decision_items.first.id, other_item.id],
      return_to: decisions_path,
      bulk: {
        bulk_action: "set_status",
        status: "completed"
      }
    }

    assert_redirected_to decisions_path
    assert_equal "completed", @decision_items.first.reload.status
    assert_equal "completed", other_item.reload.status
  end

  test "bulk status update requires selected eligible decisions" do
    log_in_as(@user)

    patch decisions_bulk_update_url, params: {
      item_ids: [],
      return_to: decisions_path,
      bulk: {
        bulk_action: "set_status",
        status: "completed"
      }
    }

    assert_redirected_to decisions_path
    assert_equal "planned", @decision_items.second.reload.status
    assert_equal "Select at least one decision.", flash[:alert]
  end

  test "bulk status update rejects statuses outside the decision bulk choices" do
    log_in_as(@user)

    patch decisions_bulk_update_url, params: {
      item_ids: [@decision_items.second.id],
      return_to: decisions_path,
      bulk: {
        bulk_action: "set_status",
        status: "to_be_confirmed"
      }
    }

    assert_redirected_to decisions_path
    assert_equal "planned", @decision_items.second.reload.status
    assert_equal "Select a valid decision status.", flash[:alert]
  end

  test "bulk status update ignores archived event and non decision items" do
    log_in_as(@user)
    non_decision = calendar_items(:ceremony)
    archived_item = create_decision_item_for_event!(
      event: create_event!(name: "Archived Gala", archived_at: 1.day.ago),
      title: "Archived Decision",
      starts_at: Time.zone.local(2025, 9, 18, 12, 0)
    )

    patch decisions_bulk_update_url, params: {
      item_ids: [non_decision.id, archived_item.id],
      return_to: decisions_path,
      bulk: {
        bulk_action: "set_status",
        status: "completed"
      }
    }

    assert_redirected_to decisions_path
    assert_not_equal "completed", non_decision.reload.status
    assert_not_equal "completed", archived_item.reload.status
    assert_equal "Select at least one decision.", flash[:alert]
  end

  test "planner sees and updates decisions only for assigned events" do
    other_event = create_event!(name: "Unassigned Wedding")
    other_item = create_decision_item_for_event!(
      event: other_event,
      title: "Confirm Rentals",
      starts_at: Time.zone.local(2025, 9, 21, 9, 0)
    )

    log_in_as(users(:one))
    get decisions_url

    assert_response :success
    assert_select "a.event-calendars__title-link", text: @decision_items.first.title, count: 1
    assert_select "a.event-calendars__title-link", text: other_item.title, count: 0

    patch decisions_bulk_update_url, params: {
      item_ids: [@decision_items.first.id, other_item.id],
      return_to: decisions_path,
      bulk: {
        bulk_action: "set_status",
        status: "completed"
      }
    }

    assert_redirected_to decisions_path
    assert_equal "completed", @decision_items.first.reload.status
    assert_not_equal "completed", other_item.reload.status
  end

  test "auto creates missing decision calendar views for represented events" do
    log_in_as(@user)
    event = create_event!(name: "Missing Decision View Wedding")
    calendar = event.run_of_show_calendar
    item = create_decision_item_for_event!(
      event: event,
      title: "Choose Linen",
      starts_at: Time.zone.local(2025, 9, 25, 9, 0)
    )

    assert_nil calendar.event_calendar_views.find_by(slug: "decision-calendar")

    get decisions_url

    assert_response :success
    view = calendar.event_calendar_views.find_by(slug: "decision-calendar")
    assert view
    expected_href = "#{event_calendar_view_path(event, view)}##{ActionView::RecordIdentifier.dom_id(item, :timeline_row)}"
    assert_select "a.event-calendars__title-link[href='#{expected_href}']", text: item.title, count: 1
  end

  private

  def create_event!(name:, archived_at: nil)
    Event.create!(
      name: name,
      starts_on: Date.new(2025, 9, 1),
      ends_on: Date.new(2025, 9, 2),
      archived_at: archived_at
    ).tap do |event|
      event.create_run_of_show_calendar!(
        name: "Run of Show",
        timezone: "UTC",
        kind: EventCalendar::KINDS[:master]
      )
    end
  end

  def create_decision_item_for_event!(event:, title:, starts_at:)
    calendar = event.run_of_show_calendar
    tag = calendar.event_calendar_tags.create!(name: "Decisions")
    calendar.calendar_items.create!(
      title: title,
      starts_at: starts_at,
      duration_minutes: 0,
      relative_offset_minutes: 0,
      event_calendar_tags: [tag]
    )
  end
end
