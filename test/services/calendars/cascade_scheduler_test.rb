require "test_helper"

module Calendars
  class CascadeSchedulerTest < ActiveSupport::TestCase
    setup do
      @calendar = event_calendars(:run_of_show)
      @ceremony = calendar_items(:ceremony)
      @reception = calendar_items(:reception)
      @afterparty = calendar_items(:afterparty)
    end

    test "updates relative items based on anchor" do
      @reception.update!(starts_at: nil)

      result = CascadeScheduler.new(@calendar).call

      @reception.reload
      assert_in_delta @ceremony.starts_at + 120.minutes, @reception.starts_at, 1
      assert_includes result.updated_item_ids, @reception.id
    end

    test "skips locked items but leaves existing time" do
      original_time = @afterparty.starts_at
      @afterparty.update!(locked: true)

      result = CascadeScheduler.new(@calendar).call

      @afterparty.reload
      assert_equal original_time.to_i, @afterparty.starts_at.to_i
      assert_includes result.skipped_locked_ids, @afterparty.id
    end

    test "raises when cycle detected" do
      @afterparty.update_columns(locked: false, starts_at: nil)
      @afterparty.update!(relative_anchor: @reception)
      @reception.update_column(:relative_anchor_id, @afterparty.id)

      assert_raises CascadeScheduler::CircularDependencyError do
        CascadeScheduler.new(@calendar).send(:compute_start_time, @reception)
      end
    end
  end
end
