require "test_helper"

class CalendarItemTest < ActiveSupport::TestCase
  setup do
    @calendar = event_calendars(:run_of_show)
    @ceremony = calendar_items(:ceremony)
    @reception = calendar_items(:reception)
  end

  test "effective starts at falls back to anchor when relative" do
    scheduler = ::Calendars::CascadeScheduler.new(@calendar)
    scheduler.call

    @reception.reload
    expected = @ceremony.starts_at + @reception.relative_offset_minutes.minutes

    assert_in_delta expected.to_i, @reception.starts_at.to_i, 1
  end

  test "prevents circular dependency" do
    cycle_item = @calendar.calendar_items.new(title: "Loop", relative_anchor: @reception, relative_offset_minutes: 15)
    @reception.relative_anchor = cycle_item

    assert_not @reception.valid?
    assert_includes @reception.errors[:relative_anchor_id], "creates a circular dependency"
  end

  test "relative anchor must be in same calendar" do
    other_calendar = event_calendars(:vendor_calendar)
    outsider = other_calendar.calendar_items.create!(title: "Other", relative_offset_minutes: 10)

    @reception.relative_anchor = outsider

    assert_not @reception.valid?
    assert_includes @reception.errors[:relative_anchor_id], "must reference an item on the same calendar"
  end
end
