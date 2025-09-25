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
  end

  test "shows grid for derived view" do
    get grid_event_calendar_view_url(@event, @view)
    assert_response :success
    assert_select "h1", text: @view.name
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
end
