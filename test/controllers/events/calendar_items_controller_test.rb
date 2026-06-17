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
      assert_select "input[name='calendar_item[guest_count]']", count: 1
      assert_select "[data-controller='generated-markdown-editor']", count: 1
      assert_select "textarea[name='calendar_item[transportation_note]'][data-generated-markdown-editor-target='source']", count: 1
      assert_select ".calendar-item-form__markdown-editor button[data-markdown-format='bold']", count: 2
      assert_select ".calendar-item-form__markdown-editor button[data-markdown-format='italic']", count: 2
      assert_select ".calendar-item-form__markdown-editor button[data-markdown-format='link']", count: 2
      assert_select ".calendar-item-form__markdown-editor button[data-markdown-format='headline']", count: 0
    end

    test "edit renders relative timing controls as a sentence with smart offset units" do
      item = calendar_items(:reception)

      get edit_event_calendar_item_url(@event, item)

      assert_response :success
      assert_select ".calendar-item-form__relative-sentence", count: 1
      assert_select "input[name='calendar_item[relative_offset_value]'][value='2']", count: 1
      assert_select "select[name='calendar_item[relative_offset_unit]'] option[selected][value='hours']", text: "Hours", count: 1
      assert_select "select[name='calendar_item[relative_anchor_id]'] option[value='']", text: "Choose an anchor...", count: 1
      assert_select "[data-relative-timing-summary]", text: /Starts 2 hours after Ceremony starts → Oct 1 5:00PM/
    end

    test "update respects anchored return_to" do
      item = calendar_items(:ceremony)
      row_anchor = ActionView::RecordIdentifier.dom_id(item, :timeline_row)
      return_to = "#{event_calendar_path(@event, q: 'Ceremony', tags: [ 'day-of' ])}##{row_anchor}"

      patch event_calendar_item_url(@event, item), params: {
        return_to:,
        calendar_item: {
          title: "Ceremony Updated",
          guest_count: "Approx. 175",
          transportation_note: "**Guests** leave from the [front drive](https://example.com/map) at 2:15 PM.",
          starts_at: "2025-10-01T15:00",
          duration_value: 45,
          duration_unit: "minutes"
        }
      }

      assert_redirected_to return_to
      assert_equal "Ceremony Updated", item.reload.title
      assert_equal "Approx. 175", item.reload.guest_count
      assert_equal "**Guests** leave from the [front drive](https://example.com/map) at 2:15 PM.", item.reload.transportation_note
    end

    test "update converts relative timing sentence fields to existing stored values" do
      item = calendar_items(:reception)
      anchor = calendar_items(:ceremony)

      patch event_calendar_item_url(@event, item), params: {
        calendar_item: {
          title: item.title,
          timing_mode: "relative",
          relative_anchor_id: anchor.id,
          relative_offset_value: "2",
          relative_offset_unit: "hours",
          relative_before: "false",
          relative_to_anchor_end: "true",
          duration_value: item.duration_minutes,
          duration_unit: "minutes"
        }
      }

      assert_redirected_to event_calendar_path(@event)
      item.reload
      assert_equal anchor.id, item.relative_anchor_id
      assert_equal 120, item.relative_offset_minutes
      assert_equal false, item.relative_before?
      assert_equal true, item.relative_to_anchor_end?
    end

    test "update maps before start selections without changing backend fields" do
      item = calendar_items(:reception)
      anchor = calendar_items(:ceremony)

      patch event_calendar_item_url(@event, item), params: {
        calendar_item: {
          title: item.title,
          timing_mode: "relative",
          relative_anchor_id: anchor.id,
          relative_offset_value: "30",
          relative_offset_unit: "minutes",
          relative_before: "true",
          relative_to_anchor_end: "false",
          duration_value: item.duration_minutes,
          duration_unit: "minutes"
        }
      }

      assert_redirected_to event_calendar_path(@event)
      item.reload
      assert_equal anchor.id, item.relative_anchor_id
      assert_equal 30, item.relative_offset_minutes
      assert_equal true, item.relative_before?
      assert_equal false, item.relative_to_anchor_end?
    end

    test "update preserves absolute starts_at semantics" do
      item = calendar_items(:ceremony)

      patch event_calendar_item_url(@event, item), params: {
        calendar_item: {
          title: item.title,
          timing_mode: "absolute",
          starts_at: "2025-10-01T16:30",
          duration_value: item.duration_minutes,
          duration_unit: "minutes"
        }
      }

      assert_redirected_to event_calendar_path(@event)
      item.reload
      assert_nil item.relative_anchor_id
      assert_equal 0, item.relative_offset_minutes
      assert_equal Time.utc(2025, 10, 1, 16, 30), item.starts_at
    end

    test "create persists item guest count and transportation note" do
      assert_difference("CalendarItem.count", 1) do
        post event_calendar_items_url(@event), params: {
          calendar_item: {
            title: "Guest Shuttle",
            starts_at: "2025-10-01T13:00",
            guest_count: "120 guests",
            transportation_note: "Board the **shuttle** at the hotel porte cochere.",
            duration_value: 30,
            duration_unit: "minutes"
          }
        }
      end

      assert_redirected_to event_calendar_path(@event)
      created_item = CalendarItem.order(:id).last
      assert_equal "120 guests", created_item.guest_count
      assert_equal "Board the **shuttle** at the hotel porte cochere.", created_item.transportation_note
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

    test "bulk update sets time label for selected items" do
      item = calendar_items(:ceremony)

      patch bulk_update_event_calendar_items_url(@event), params: {
        item_ids: [item.id],
        bulk: {
          bulk_action: "set_time_label",
          time_caption: "Morning"
        }
      }

      assert_redirected_to event_calendar_path(@event)
      assert_equal "Morning", item.reload.time_caption
    end

    test "bulk update adds pp members for selected items" do
      item = calendar_items(:ceremony)

      patch bulk_update_event_calendar_items_url(@event), params: {
        item_ids: [item.id],
        bulk: {
          bulk_action: "add_team_members",
          team_member_ids: [users(:two).id]
        }
      }

      assert_redirected_to event_calendar_path(@event)
      assert_equal [users(:one).id, users(:two).id].sort, item.reload.team_member_ids.sort
    end

    test "bulk update sets other people for selected items" do
      item = calendar_items(:ceremony)

      patch bulk_update_event_calendar_items_url(@event), params: {
        item_ids: [item.id],
        bulk: {
          bulk_action: "set_additional_team_members",
          additional_team_members: "DJ; Florist"
        }
      }

      assert_redirected_to event_calendar_path(@event)
      assert_equal "DJ; Florist", item.reload.additional_team_members
    end

    test "bulk update deletes selected items and respects safe return path" do
      item = calendar_items(:reception)
      return_to = event_calendar_view_path(
        @event,
        event_calendar_views(:vendor_view),
        q: "Reception",
        tags: [ "vendor" ]
      )

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
