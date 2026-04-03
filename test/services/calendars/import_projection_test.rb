require "test_helper"

module Calendars
  class ImportProjectionTest < ActiveSupport::TestCase
    setup do
      @source_event = events(:one)
      @destination_event = events(:two)
      @destination_calendar = @destination_event.event_calendars.create!(
        name: "Run of Show",
        timezone: "UTC"
      )
      @vendor_view = event_calendar_views(:vendor_view)
    end

    test "projects preserved relative items onto a custom anchor date" do
      anchor = calendar_items(:ceremony)
      dependent = calendar_items(:reception)
      anchor_date = Date.new(2025, 11, 20)

      result = projection(selected_item_ids: [anchor.id, dependent.id], anchor_date: anchor_date)
      anchor_plan = result.item_plans.find { |plan| plan.source_item == anchor }
      dependent_plan = result.item_plans.find { |plan| plan.source_item == dependent }

      refute result.anchor_date_missing
      assert_time_close shifted_time(anchor.starts_at, anchor_date: anchor_date), anchor_plan.projected_start_at
      assert_time_close shifted_time(anchor.effective_ends_at, anchor_date: anchor_date), anchor_plan.projected_end_at

      assert dependent_plan.preserve_relative_anchor
      refute dependent_plan.fallback_to_absolute
      assert_nil dependent_plan.import_attributes[:starts_at]
      assert_equal dependent.relative_offset_minutes, dependent_plan.import_attributes[:relative_offset_minutes]
      assert_equal dependent.relative_before?, dependent_plan.import_attributes[:relative_before]
      assert_equal dependent.relative_to_anchor_end?, dependent_plan.import_attributes[:relative_to_anchor_end]
      assert_time_close shifted_time(dependent.effective_starts_at, anchor_date: anchor_date), dependent_plan.projected_start_at
      assert_time_close shifted_time(dependent.effective_ends_at, anchor_date: anchor_date), dependent_plan.projected_end_at
    end

    test "uses filtered view items for all mode projections" do
      result = projection(
        source_timeline_ref: "view:#{@vendor_view.id}",
        selection_mode: "all",
        selected_item_ids: []
      )

      assert_equal [calendar_items(:reception)], result.selected_source_items
      assert_equal 1, result.fallback_to_absolute_count
      assert_equal 0, result.missing_time_count
    end

    test "does not require anchor date or shift when the source event has no start date" do
      source_event = Event.create!(name: "Floating source")
      source_calendar = source_event.event_calendars.create!(name: "Run of Show", timezone: "UTC")
      source_item = source_calendar.calendar_items.create!(
        title: "Loose schedule",
        starts_at: Time.utc(2025, 12, 1, 9, 0, 0),
        duration_minutes: 30,
        position: 0
      )

      result = projection(
        source_event: source_event,
        selected_item_ids: [source_item.id],
        anchor_date: Date.new(2026, 1, 5)
      )
      plan = result.item_plans.first

      refute result.anchor_shift_supported
      refute result.anchor_date_missing
      assert_time_close source_item.starts_at, plan.projected_start_at
      assert_time_close source_item.effective_ends_at, plan.projected_end_at
      assert_time_close source_item.starts_at, plan.import_attributes[:starts_at]
    end

    test "flags missing anchor dates when the source event has a start date" do
      source_item = calendar_items(:ceremony)

      result = projection(selected_item_ids: [source_item.id], anchor_date: nil)

      assert result.anchor_shift_supported
      assert result.anchor_date_missing
      assert_time_close source_item.starts_at, result.item_plans.first.projected_start_at
    end

    test "computes the next batch tag name from the highest existing suffix" do
      names = ["Imported", "imported-2", "notes", "IMPORTED-7"]

      assert_equal "imported-8", ImportProjection.next_batch_tag_name(names)
    end

    private

    def projection(source_event: @source_event, source_timeline_ref: "run_of_show", selection_mode: "selected", selected_item_ids: [], anchor_date: @destination_event.starts_on, batch_tag_enabled: false)
      ImportProjection.new(
        destination_event: @destination_event,
        destination_calendar: @destination_calendar,
        source_event: source_event,
        source_timeline_ref: source_timeline_ref,
        selection_mode: selection_mode,
        selected_item_ids: selected_item_ids,
        anchor_date: anchor_date,
        batch_tag_enabled: batch_tag_enabled
      ).call
    end

    def shifted_time(time_value, anchor_date:)
      return nil if time_value.blank?

      shift_minutes = ((anchor_date - @source_event.starts_on).to_i * 24 * 60)
      time_value + shift_minutes.minutes
    end

    def assert_time_close(expected, actual)
      assert_in_delta expected.to_f, actual.to_f, 1
    end
  end
end
