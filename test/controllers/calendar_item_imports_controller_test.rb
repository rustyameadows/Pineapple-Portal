require "test_helper"

class CalendarItemImportsControllerTest < ActionDispatch::IntegrationTest
  setup do
    log_in_as(users(:one))
    @event = events(:two)
    @source_event = events(:one)
    @source_calendar = event_calendars(:run_of_show)
    @decision_view = event_calendar_views(:decision_view)
    @vendor_view = event_calendar_views(:vendor_view)
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
    assert_select "input[type='date'][name='anchor_date'][value='#{@event.starts_on}']"
    assert_select "input[type='checkbox'][name='batch_tag_enabled']"
  end

  test "defaults anchor date to the source event when the destination event has no start date" do
    destination_event = Event.create!(name: "Floating destination")

    get event_calendar_item_import_url(destination_event), params: {
      source_event_id: @source_event.id,
      source_timeline_ref: "run_of_show"
    }

    assert_response :success
    assert_select "input[type='date'][name='anchor_date'][value='#{@source_event.starts_on}']"
  end

  test "disables anchor controls when the source event has no start date" do
    source_event = Event.create!(name: "Floating source")
    source_calendar = source_event.event_calendars.create!(name: "Run of Show", timezone: "UTC")
    source_calendar.calendar_items.create!(
      title: "Loose schedule",
      starts_at: Time.utc(2025, 12, 1, 9, 0, 0),
      duration_minutes: 30,
      position: 0
    )

    get event_calendar_item_import_url(@event), params: {
      source_event_id: source_event.id,
      source_timeline_ref: "run_of_show"
    }

    assert_response :success
    assert_select "input[type='date'][name='anchor_date'][disabled='disabled']"
    assert_match "scheduled items will keep their original dates and times", response.body
  end

  test "rejects invalid source event" do
    post event_calendar_item_import_url(@event), params: {
      source_event_id: -1,
      source_timeline_ref: "run_of_show",
      selection_mode: "all",
      anchor_date: @event.starts_on
    }

    assert_response :unprocessable_content
    assert_match "Select a source event to import from.", response.body
  end

  test "rejects invalid source timeline" do
    post event_calendar_item_import_url(@event), params: {
      source_event_id: @source_event.id,
      source_timeline_ref: "view:999999",
      selection_mode: "all",
      anchor_date: @event.starts_on
    }

    assert_response :unprocessable_content
    assert_match "Select a source timeline.", response.body
  end

  test "rejects selected mode with no selected item ids" do
    post event_calendar_item_import_url(@event), params: {
      source_event_id: @source_event.id,
      source_timeline_ref: "run_of_show",
      selection_mode: "selected",
      anchor_date: @event.starts_on,
      item_ids: []
    }

    assert_response :unprocessable_content
    assert_match "Select at least one item to import.", response.body
  end

  test "rejects selected ids that do not match the chosen timeline" do
    post event_calendar_item_import_url(@event), params: {
      source_event_id: @source_event.id,
      source_timeline_ref: "view:#{@vendor_view.id}",
      selection_mode: "selected",
      anchor_date: @event.starts_on,
      item_ids: [calendar_items(:ceremony).id]
    }

    assert_response :unprocessable_content
    assert_match "No items matched the selected import options.", response.body
  end

  test "preserves anchor date and batch tag choice on validation failure" do
    post event_calendar_item_import_url(@event), params: {
      source_event_id: @source_event.id,
      source_timeline_ref: "run_of_show",
      selection_mode: "selected",
      anchor_date: "2025-11-20",
      batch_tag_enabled: "1",
      item_ids: []
    }

    assert_response :unprocessable_content
    assert_select "input[type='date'][name='anchor_date'][value='2025-11-20']"
    assert_select "input[type='checkbox'][name='batch_tag_enabled'][checked='checked']"
  end

  test "requires anchor date when the source event has a start date" do
    post event_calendar_item_import_url(@event), params: {
      source_event_id: @source_event.id,
      source_timeline_ref: "run_of_show",
      selection_mode: "all",
      anchor_date: ""
    }

    assert_response :unprocessable_content
    assert_match "Choose an anchor date to preview and import this timeline.", response.body
  end

  test "imports all listed items from a filtered timeline view" do
    assert_difference("CalendarItem.count", 1) do
      post event_calendar_item_import_url(@event), params: {
        source_event_id: @source_event.id,
        source_timeline_ref: "view:#{@vendor_view.id}",
        selection_mode: "all",
        anchor_date: "2025-11-20"
      }
    end

    assert_redirected_to event_calendar_url(@event)
    assert_equal ["Reception"], @event.reload.run_of_show_calendar.calendar_items.order(:position).pluck(:title)
  end

  test "allows imports without an anchor date when the source event has no start date" do
    source_event = Event.create!(name: "Floating source")
    source_calendar = source_event.event_calendars.create!(name: "Run of Show", timezone: "UTC")
    source_item = source_calendar.calendar_items.create!(
      title: "Loose schedule",
      starts_at: Time.utc(2025, 12, 1, 9, 0, 0),
      duration_minutes: 30,
      position: 0
    )

    assert_difference("CalendarItem.count", 1) do
      post event_calendar_item_import_url(@event), params: {
        source_event_id: source_event.id,
        source_timeline_ref: "run_of_show",
        selection_mode: "selected",
        anchor_date: "",
        item_ids: [source_item.id]
      }
    end

    assert_redirected_to event_calendar_url(@event)
  end

  test "imports selected items and redirects to run of show" do
    source_item = calendar_items(:ceremony)

    assert_difference("CalendarItem.count", 1) do
      post event_calendar_item_import_url(@event), params: {
        source_event_id: @source_event.id,
        source_timeline_ref: "run_of_show",
        selection_mode: "selected",
        anchor_date: "2025-11-20",
        batch_tag_enabled: "1",
        item_ids: [source_item.id]
      }
    end

    assert_redirected_to event_calendar_url(@event)
    follow_redirect!
    assert_match "Tagged this import batch as imported.", response.body
  end
end
