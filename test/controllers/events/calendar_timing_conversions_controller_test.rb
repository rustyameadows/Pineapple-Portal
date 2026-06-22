require "test_helper"

module Events
  class CalendarTimingConversionsControllerTest < ActionDispatch::IntegrationTest
    setup do
      log_in_as(users(:one))
      @event = events(:one)
      @calendar = event_calendars(:run_of_show)
      @ceremony = calendar_items(:ceremony)
    end

    test "converts selected item to relative timing" do
      target = @calendar.calendar_items.create!(
        title: "Cocktail Hour",
        starts_at: Time.zone.local(2025, 10, 1, 17, 30),
        duration_minutes: 60
      )

      post event_calendar_timing_conversion_url(@event), params: {
        return_to: event_calendar_path(@event),
        timing_conversion: {
          mode: "relative",
          target_item_id: target.id,
          anchor_item_id: @ceremony.id,
          anchor_point: "end"
        }
      }

      assert_redirected_to event_calendar_path(@event)
      assert_equal "Relative timing updated.", flash[:notice]
      target.reload
      assert_equal @ceremony.id, target.relative_anchor_id
      assert_equal 105, target.relative_offset_minutes
      assert_not target.relative_before?
      assert target.relative_to_anchor_end?
    end

    test "converts selected item to absolute timing" do
      item = calendar_items(:reception)
      projected_start = item.effective_starts_at

      post event_calendar_timing_conversion_url(@event), params: {
        return_to: event_calendar_path(@event),
        timing_conversion: {
          mode: "absolute",
          target_item_id: item.id
        }
      }

      assert_redirected_to event_calendar_path(@event)
      assert_equal "Absolute timing set.", flash[:notice]
      item.reload
      assert_nil item.relative_anchor_id
      assert_equal projected_start, item.starts_at
    end

    test "redirects with alert when relative conversion is invalid" do
      post event_calendar_timing_conversion_url(@event), params: {
        return_to: event_calendar_path(@event),
        timing_conversion: {
          mode: "relative",
          target_item_id: @ceremony.id,
          anchor_item_id: @ceremony.id,
          anchor_point: "start"
        }
      }

      assert_redirected_to event_calendar_path(@event)
      assert_equal "Choose two different calendar items.", flash[:alert]
      assert_nil @ceremony.reload.relative_anchor_id
    end
  end
end
