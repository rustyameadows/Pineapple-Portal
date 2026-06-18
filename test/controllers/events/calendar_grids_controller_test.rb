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
    assert_select ".event-layout.event-layout--grid", count: 1
    assert_select ".event-sidebar", count: 0
    assert_select ".event-section__subtitle", count: 0
    assert_select "a[href='#{event_calendar_path(@event)}']", text: "View mode", count: 1
    assert_select ".calendar-grid__column-controls", count: 1
    assert_select "input[data-grid-column-toggle][value='title'][checked='checked']", count: 1
    assert_select "input[data-grid-column-toggle][value='start'][checked='checked']", count: 1
    assert_select "input[data-grid-column-toggle][value='duration'][checked='checked']", count: 1
    assert_select "input[data-grid-column-toggle][value='anchor'][checked='checked']", count: 1
    assert_select "input[data-grid-column-toggle][value='relation'][checked='checked']", count: 1
    assert_select "input[data-grid-column-toggle][value='location'][checked='checked']", count: 1
    assert_select "input[data-grid-column-toggle][value='vendor'][checked='checked']", count: 1
    assert_select "input[data-grid-column-toggle][value='notes'][checked='checked']", count: 1
    assert_select "input[data-grid-column-toggle][value='status'][checked='checked']", count: 0
    assert_select "input[data-grid-column-toggle][value='tags'][checked='checked']", count: 0
    assert_select "th[data-grid-column='status'][hidden]", text: "Status", count: 1
    assert_select "th[data-grid-column='tags'][hidden]", text: "Tags", count: 1
    assert_select ".calendar-grid__bulk", count: 0
    assert_select ".calendar-grid__table-wrapper", count: 1
    assert_select ".event-calendars__bulk-toolbar[hidden]", count: 1
    assert_select "form#calendar-grid-bulk-form select[name='bulk[bulk_action]']"
    assert_select "form#calendar-grid-bulk-form option[value='set_vendor']", text: "Set vendor", count: 1
    assert_select "[data-calendar-bulk-edit-target='statusRow'][hidden]", count: 1
    assert_select "input.event-calendars__bulk-checkbox[data-calendar-bulk-edit-target='checkbox']", minimum: 1
    assert_select "option[value='set_locked']", count: 0
    assert_select "th", text: "Locked", count: 0
    assert_select "input[name='calendar_item[locked]']", count: 0
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

  test "grid renders relative timing and duration as display intent controls" do
    get grid_event_calendar_url(@event)

    assert_response :success
    assert_select "input[name='calendar_item[relative_offset_display_value]'][value='0']"
    assert_select "select[name='calendar_item[relative_offset_display_unit]'] option[selected][value='days']", text: "Days"
    assert_select "input[name='calendar_item[relative_offset_display_hours]'][value='2']"
    assert_select "input[name='calendar_item[relative_offset_display_minutes]'][value='0']"
    assert_select "input[name='calendar_item[duration_display_value]']"
    assert_select "select[name='calendar_item[duration_display_unit]'] option[value='days']", text: "Days"
    assert_select "input[name='calendar_item[duration_display_hours]']"
    assert_select "input[name='calendar_item[duration_display_minutes]']"
    assert_select "[data-relative-summary]", text: /Starts 2 hr after Ceremony starts → Oct 1 5:00PM/
    assert_select "[data-relative-summary]", text: "Absolute start"
    assert_no_match "120 min", response.body
  end

  test "grid anchor options use effective relative times" do
    get grid_event_calendar_url(@event)

    assert_response :success
    assert_includes response.body, "Reception (Oct 1 5:00 PM"
  end

  test "updates a calendar item" do
    @item.update!(locked: true)

    patch grid_item_event_calendar_url(@event, item_id: @item), params: {
      calendar_item: {
        title: "Updated Ceremony",
        starts_at: "2025-10-01T16:00",
        duration_display_value: "0",
        duration_display_unit: "days",
        duration_display_hours: "1",
        duration_display_minutes: "0",
        status: "in_progress",
        event_calendar_tag_ids: [event_calendar_tags(:vendor).id]
      }
    }

    assert_redirected_to grid_event_calendar_url(@event)
    @item.reload
    assert_equal "Updated Ceremony", @item.title
    assert_equal 60, @item.duration_minutes
    assert_equal 0, @item.duration_display_value
    assert_equal "days", @item.duration_display_unit
    assert_equal 1, @item.duration_display_hours
    assert_equal 0, @item.duration_display_minutes
    assert_equal "in_progress", @item.status
    assert @item.locked?
    assert_equal [event_calendar_tags(:vendor).id], @item.event_calendar_tag_ids.sort
  end

  test "updates relative timing from display intent controls" do
    item = calendar_items(:reception)
    anchor = calendar_items(:ceremony)

    patch grid_item_event_calendar_url(@event, item_id: item), params: {
      calendar_item: {
        title: item.title,
        duration_display_value: "0",
        duration_display_unit: "days",
        duration_display_hours: "3",
        duration_display_minutes: "0",
        status: item.status,
        relative_anchor_id: anchor.id,
        relative_offset_display_value: "0",
        relative_offset_display_unit: "days",
        relative_offset_display_hours: "6.5",
        relative_offset_display_minutes: "0",
        relative_before: "false",
        relative_to_anchor_end: "false",
        event_calendar_tag_ids: []
      }
    }

    assert_redirected_to grid_event_calendar_url(@event)
    item.reload
    assert_equal 390, item.relative_offset_minutes
    assert_equal 0, item.relative_offset_display_value
    assert_equal "days", item.relative_offset_display_unit
    assert_equal 6, item.relative_offset_display_hours
    assert_equal 30, item.relative_offset_display_minutes
    assert_not item.relative_before?
    assert_not item.relative_to_anchor_end?
  end

  test "updates relative timing for decision calendar week offsets" do
    item = calendar_items(:reception)
    anchor = calendar_items(:ceremony)

    patch grid_item_event_calendar_url(@event, item_id: item), params: {
      calendar_item: {
        title: item.title,
        duration_display_value: "0",
        duration_display_unit: "days",
        duration_display_hours: "3",
        duration_display_minutes: "0",
        status: item.status,
        relative_anchor_id: anchor.id,
        relative_offset_display_value: "2",
        relative_offset_display_unit: "weeks",
        relative_offset_display_hours: "0",
        relative_offset_display_minutes: "0",
        relative_before: "false",
        relative_to_anchor_end: "false",
        event_calendar_tag_ids: []
      }
    }

    assert_redirected_to grid_event_calendar_url(@event)
    item.reload
    assert_equal 20_160, item.relative_offset_minutes
    assert_equal 2, item.relative_offset_display_value
    assert_equal "weeks", item.relative_offset_display_unit
    assert_equal 0, item.relative_offset_display_hours
    assert_equal 0, item.relative_offset_display_minutes
  end

  test "updates relative direction and anchor point selections" do
    item = calendar_items(:reception)
    anchor = calendar_items(:ceremony)

    patch grid_item_event_calendar_url(@event, item_id: item), params: {
      calendar_item: {
        title: item.title,
        duration_display_value: "0",
        duration_display_unit: "days",
        duration_display_hours: "3",
        duration_display_minutes: "0",
        status: item.status,
        relative_anchor_id: anchor.id,
        relative_offset_display_value: "0",
        relative_offset_display_unit: "days",
        relative_offset_display_hours: "0",
        relative_offset_display_minutes: "30",
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

  test "applies shared bulk toolbar vendor update and respects return_to" do
    return_to = "#{grid_event_calendar_path(@event)}?grid=1"

    patch grid_bulk_event_calendar_url(@event), params: {
      return_to:,
      item_ids: [@item.id],
      bulk: {
        bulk_action: "set_vendor",
        vendor_name: "Shared Toolbar Vendor"
      }
    }

    assert_redirected_to return_to
    assert_equal "Shared Toolbar Vendor", @item.reload.vendor_name
  end

  test "does not expose bulk lock updates in grid mode" do
    get grid_event_calendar_url(@event)

    assert_response :success
    assert_select "select[name='bulk[bulk_action]'] option", text: "Update lock state", count: 0
    assert_no_match "Lock selected", response.body
    assert_no_match "Unlock selected", response.body
  end
end
