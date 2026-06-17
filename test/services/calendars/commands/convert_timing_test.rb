require "test_helper"

module Calendars
  module Commands
    class ConvertTimingTest < ActiveSupport::TestCase
      setup do
        @calendar = event_calendars(:run_of_show)
        @ceremony = calendar_items(:ceremony)
      end

      test "converts an absolute item to relative timing from an anchor end" do
        target = @calendar.calendar_items.create!(
          title: "Cocktail Hour",
          starts_at: Time.zone.local(2025, 10, 1, 17, 30),
          duration_minutes: 60
        )

        result = ConvertToRelative.new(calendar: @calendar).call(
          target_item_id: target.id,
          anchor_item_id: @ceremony.id,
          anchor_point: "end"
        )

        assert_predicate result, :success?
        target.reload
        assert_equal @ceremony.id, target.relative_anchor_id
        assert_equal 105, target.relative_offset_minutes
        assert_equal 0, target.relative_offset_display_value
        assert_equal "days", target.relative_offset_display_unit
        assert_equal 1, target.relative_offset_display_hours
        assert_equal 45, target.relative_offset_display_minutes
        assert_not target.relative_before?
        assert target.relative_to_anchor_end?
        assert_equal Time.zone.local(2025, 10, 1, 17, 30), target.effective_starts_at
      end

      test "converts an absolute item to before an anchor start" do
        target = @calendar.calendar_items.create!(
          title: "Prelude",
          starts_at: Time.zone.local(2025, 10, 1, 14, 30)
        )

        result = ConvertToRelative.new(calendar: @calendar).call(
          target_item_id: target.id,
          anchor_item_id: @ceremony.id,
          anchor_point: "start"
        )

        assert_predicate result, :success?
        target.reload
        assert_equal 30, target.relative_offset_minutes
        assert target.relative_before?
        assert_not target.relative_to_anchor_end?
      end

      test "converts an existing relative item to absolute timing" do
        item = calendar_items(:reception)
        projected_start = item.effective_starts_at

        result = ConvertToAbsolute.new(calendar: @calendar).call(item_id: item.id)

        assert_predicate result, :success?
        item.reload
        assert_nil item.relative_anchor_id
        assert_equal projected_start, item.starts_at
        assert_equal 0, item.relative_offset_minutes
        assert_equal 0, item.relative_offset_display_value
        assert_equal "days", item.relative_offset_display_unit
        assert_equal 0, item.relative_offset_display_hours
        assert_equal 0, item.relative_offset_display_minutes
        assert_not item.relative_before?
        assert_not item.relative_to_anchor_end?
      end

      test "rejects converting an item relative to itself" do
        result = ConvertToRelative.new(calendar: @calendar).call(
          target_item_id: @ceremony.id,
          anchor_item_id: @ceremony.id,
          anchor_point: "start"
        )

        assert_not result.success?
        assert_equal "Choose two different calendar items.", result.message
      end
    end
  end
end
