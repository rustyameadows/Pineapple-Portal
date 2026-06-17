require "test_helper"

class Events::CalendarGridsControllerTest < ActionDispatch::IntegrationTest
  setup do
    log_in_as(users(:one))
    @event = events(:one)
    @calendar = event_calendars(:run_of_show)
    @view = event_calendar_views(:vendor_view)
    @item = calendar_items(:ceremony)
  end

  test "shows grid for run of show" do
    get grid_event_calendar_url(@event)
    assert_response :success
    assert_select "h1", text: @calendar.name
    assert_select "form#calendar-grid-bulk-form select[name='bulk[bulk_action]']"
  end

  test "run of show links to grid edit mode" do
    get event_calendar_url(@event)

    assert_response :success
    assert_select "a[href='#{grid_event_calendar_path(@event)}']", text: "Edit mode"
  end

  test "shows grid for derived view" do
    get grid_event_calendar_view_url(@event, @view)
    assert_response :success
    assert_select "h1", text: @view.name
  end

  test "grid renders relative timing in friendly units with projected summary" do
    get grid_event_calendar_url(@event)

    assert_response :success
    assert_select "input[name='calendar_item[relative_offset_value]'][value='2']"
    assert_select "select[name='calendar_item[relative_offset_unit]'] option[selected][value='hours']", text: "Hours"
    assert_select "[data-relative-summary]", text: /Starts 2 hours after Ceremony starts → Oct 1 5:00PM/
    assert_select "[data-relative-summary]", text: "Absolute start"
    assert_no_match "120 min", response.body
  end

  test "grid anchor options use effective relative times" do
    get grid_event_calendar_url(@event)

    assert_response :success
    assert_includes response.body, "Reception (Oct 1 5:00 PM"
  end

  test "updates a calendar item" do
    patch grid_item_event_calendar_url(@event, item_id: @item), params: {
      calendar_item: {
        title: "Updated Ceremony",
        starts_at: "2025-10-01T16:00",
        duration_minutes: 60,
        status: "in_progress",
        locked: "1",
        event_calendar_tag_ids: [event_calendar_tags(:vendor).id]
      }
    }

    assert_redirected_to grid_event_calendar_url(@event)
    @item.reload
    assert_equal "Updated Ceremony", @item.title
    assert_equal "in_progress", @item.status
    assert @item.locked?
    assert_equal [event_calendar_tags(:vendor).id], @item.event_calendar_tag_ids.sort
  end

  test "updates relative timing from value and unit controls" do
    item = calendar_items(:reception)
    anchor = calendar_items(:ceremony)

    patch grid_item_event_calendar_url(@event, item_id: item), params: {
      calendar_item: {
        title: item.title,
        duration_minutes: item.duration_minutes,
        status: item.status,
        locked: "0",
        relative_anchor_id: anchor.id,
        relative_offset_value: "2",
        relative_offset_unit: "hours",
        relative_before: "false",
        relative_to_anchor_end: "false",
        event_calendar_tag_ids: []
      }
    }

    assert_redirected_to grid_event_calendar_url(@event)
    item.reload
    assert_equal 120, item.relative_offset_minutes
    assert_not item.relative_before?
    assert_not item.relative_to_anchor_end?
  end

  test "updates relative direction and anchor point selections" do
    item = calendar_items(:reception)
    anchor = calendar_items(:ceremony)

    patch grid_item_event_calendar_url(@event, item_id: item), params: {
      calendar_item: {
        title: item.title,
        duration_minutes: item.duration_minutes,
        status: item.status,
        locked: "0",
        relative_anchor_id: anchor.id,
        relative_offset_value: "30",
        relative_offset_unit: "minutes",
        relative_before: "true",
        relative_to_anchor_end: "true",
        event_calendar_tag_ids: []
      }
    }

    assert_redirected_to grid_event_calendar_url(@event)
    item.reload
    assert_equal 30, item.relative_offset_minutes
    assert item.relative_before?
    assert item.relative_to_anchor_end?
  end

  test "applies bulk status update" do
    patch grid_bulk_event_calendar_url(@event), params: {
      item_ids: [@item.id],
      bulk: {
        bulk_action: "set_status",
        status: "completed"
      }
    }

    assert_redirected_to grid_event_calendar_url(@event)
    assert_equal "completed", @item.reload.status
  end

  test "applies bulk tag addition" do
    patch grid_bulk_event_calendar_url(@event), params: {
      item_ids: [@item.id],
      bulk: {
        bulk_action: "add_tags",
        tag_ids: [event_calendar_tags(:day_of).id]
      }
    }

    assert_redirected_to grid_event_calendar_url(@event)
    assert_includes @item.reload.event_calendar_tag_ids, event_calendar_tags(:day_of).id
  end

  test "applies bulk lock update" do
    patch grid_bulk_event_calendar_url(@event), params: {
      item_ids: [@item.id],
      bulk: {
        bulk_action: "set_locked",
        locked: "1"
      }
    }

    assert_redirected_to grid_event_calendar_url(@event)
    assert_predicate @item.reload, :locked?
  end
end
