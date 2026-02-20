require "test_helper"

class CalendarItemImportsControllerTest < ActionDispatch::IntegrationTest
  setup do
    log_in_as(users(:one))
    @event = events(:two)
    @source_event = events(:one)
    @source_calendar = event_calendars(:run_of_show)
    @decision_view = event_calendar_views(:decision_view)
  end

  test "shows import page and source selectors" do
    get event_calendar_item_import_url(@event)

    assert_response :success
    assert_select "h1", text: "Import timeline items"
    assert_select "select[name='source_event_id']"
    assert_select "select[name='source_timeline_ref']"
  end

  test "loads source timeline options and item list" do
    get event_calendar_item_import_url(@event), params: {
      source_event_id: @source_event.id,
      source_timeline_ref: "run_of_show"
    }

    assert_response :success
    assert_select "option[value='run_of_show']"
    assert_select "option[value='view:#{@decision_view.id}']"
    assert_select "input[type='checkbox'][name='item_ids[]']", minimum: 1
  end

  test "rejects invalid source event" do
    post event_calendar_item_import_url(@event), params: {
      source_event_id: -1,
      source_timeline_ref: "run_of_show",
      selection_mode: "all"
    }

    assert_response :unprocessable_content
    assert_match "Select a source event to import from.", response.body
  end

  test "rejects invalid source timeline" do
    post event_calendar_item_import_url(@event), params: {
      source_event_id: @source_event.id,
      source_timeline_ref: "view:999999",
      selection_mode: "all"
    }

    assert_response :unprocessable_content
    assert_match "Select a source timeline.", response.body
  end

  test "rejects selected mode with no selected item ids" do
    post event_calendar_item_import_url(@event), params: {
      source_event_id: @source_event.id,
      source_timeline_ref: "run_of_show",
      selection_mode: "selected",
      item_ids: []
    }

    assert_response :unprocessable_content
    assert_match "Select at least one item to import.", response.body
  end

  test "imports selected items and redirects to run of show" do
    source_item = calendar_items(:ceremony)

    assert_difference("CalendarItem.count", 1) do
      post event_calendar_item_import_url(@event), params: {
        source_event_id: @source_event.id,
        source_timeline_ref: "run_of_show",
        selection_mode: "selected",
        item_ids: [source_item.id]
      }
    end

    assert_redirected_to event_calendar_url(@event)
  end
end
