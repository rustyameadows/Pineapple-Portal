require "test_helper"

module Events
  class CalendarItemsControllerTest < ActionDispatch::IntegrationTest
    setup do
      log_in_as(users(:one))
      @event = events(:one)
      @calendar = event_calendars(:run_of_show)
    end

    test "new preselects default tag when name matches case-insensitively" do
      tag = @calendar.event_calendar_tags.create!(name: "Decisions")

      get new_event_calendar_item_url(@event), params: { default_tag_name: "decisions" }

      assert_response :success
      assert_select "input#calendar_item_tag_#{tag.id}[type='checkbox'][name='calendar_item[event_calendar_tag_ids][]'][checked]", count: 1
    end

    test "new does not create or preselect tag when default tag name is missing" do
      existing_tag_count = @calendar.event_calendar_tags.count

      get new_event_calendar_item_url(@event), params: { default_tag_name: "Missing Decisions Tag" }

      assert_response :success
      assert_equal existing_tag_count, @calendar.event_calendar_tags.count
      assert_select "input[type='checkbox'][name='calendar_item[event_calendar_tag_ids][]'][checked]", count: 0
    end

    test "edit renders form-backed delete controls for persisted items" do
      item = calendar_items(:ceremony)
      return_to = event_calendar_path(@event)

      get edit_event_calendar_item_url(@event, item), params: { return_to: return_to }

      assert_response :success
      assert_select "a[data-turbo-method='delete'][data-impact-delete]", count: 0
      assert_select "button[data-impact-delete][form='calendar-item-delete-form-#{item.id}']", count: 1
      assert_select "form#calendar-item-delete-form-#{item.id}[data-turbo-confirm]", count: 0
      assert_select "form#calendar-item-delete-form-#{item.id}[action='#{event_calendar_item_path(@event, item)}'][method='post']" do
        assert_select "input[name='_method'][value='delete']", count: 1
        assert_select "input[name='return_to'][value='#{return_to}']", count: 1
      end
    end

    test "edit keeps turbo confirm on delete form when no dependents exist" do
      item = calendar_items(:afterparty)

      get edit_event_calendar_item_url(@event, item)

      assert_response :success
      assert_select "form#calendar-item-delete-form-#{item.id}[data-turbo-confirm='Remove this calendar item?']", count: 1
    end

    test "destroy removes item and respects safe return path" do
      item = calendar_items(:afterparty)

      assert_difference("CalendarItem.count", -1) do
        delete event_calendar_item_url(@event, item), params: { return_to: event_calendar_path(@event) }
      end

      assert_redirected_to event_calendar_path(@event)
    end

    test "bulk update adds tags to selected items only" do
      ceremony = calendar_items(:ceremony)
      reception = calendar_items(:reception)
      tag = event_calendar_tags(:day_of)

      patch bulk_update_event_calendar_items_url(@event), params: {
        item_ids: [ceremony.id],
        bulk: {
          bulk_action: "add_tags",
          tag_ids: [tag.id]
        }
      }

      assert_redirected_to event_calendar_path(@event)
      assert_includes ceremony.reload.event_calendar_tag_ids, tag.id
      assert_not_includes reception.reload.event_calendar_tag_ids, tag.id
    end

    test "bulk update clears vendor for selected items" do
      item = calendar_items(:decision_flowers)

      patch bulk_update_event_calendar_items_url(@event), params: {
        item_ids: [item.id],
        bulk: {
          bulk_action: "clear_vendor"
        }
      }

      assert_redirected_to event_calendar_path(@event)
      assert_nil item.reload.vendor_name
    end

    test "bulk update deletes selected items and respects safe return path" do
      item = calendar_items(:reception)
      return_to = event_calendar_view_path(@event, event_calendar_views(:vendor_view))

      assert_difference("CalendarItem.count", -1) do
        patch bulk_update_event_calendar_items_url(@event), params: {
          item_ids: [item.id],
          bulk: {
            bulk_action: "delete_items"
          },
          return_to:
        }
      end

      assert_redirected_to return_to
    end

    test "bulk update requires a selected item" do
      patch bulk_update_event_calendar_items_url(@event), params: {
        bulk: {
          bulk_action: "delete_items"
        }
      }

      assert_redirected_to event_calendar_path(@event)
      follow_redirect!
      assert_includes response.body, "Select at least one item."
    end
  end
end
