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

  test "effective ends at includes duration" do
    assert_in_delta @ceremony.starts_at + (@ceremony.duration_minutes.minutes),
                    @ceremony.effective_ends_at,
                    1
  end

  test "relative to anchor end uses anchor duration" do
    cleanup = @calendar.calendar_items.create!(
      title: "Cleanup",
      relative_anchor: @ceremony,
      relative_offset_minutes: 15,
      relative_to_anchor_end: true
    )

    ::Calendars::CascadeScheduler.new(@calendar).call
    cleanup.reload

    expected = @ceremony.starts_at + @ceremony.duration_minutes.minutes + 15.minutes
    assert_in_delta expected, cleanup.starts_at, 1
  end

  test "parses start time in calendar timezone" do
    @calendar.update!(timezone: "America/Los_Angeles")
    item = @calendar.calendar_items.new(title: "Soundcheck")

    item.starts_at = "2025-10-01T00:00"
    item.save!

    local_time = item.starts_at.in_time_zone(@calendar.timezone)
    expected = Time.use_zone(@calendar.timezone) { Time.zone.parse("2025-10-01 00:00") }
    assert_in_delta expected.to_i, local_time.to_i, 1
  end

  test "all day toggle coerces to midnight" do
    @calendar.update!(timezone: "America/New_York")
    item = @calendar.calendar_items.new(title: "Walkthrough")
    item.all_day_mode = "1"
    item.all_day_date = "2025-10-02"

    item.starts_at = "2025-10-02"
    item.save!

    assert item.all_day?
    local_time = item.starts_at.in_time_zone(@calendar.timezone)
    assert_equal 0, local_time.hour
    assert_equal 0, local_time.min
  end

  test "midnight start without toggle still reads as all day" do
    item = calendar_items(:ceremony)
    item.update!(starts_at: item.starts_at.change(hour: 0, min: 0))

    assert item.all_day?
  end

  test "defaults status to planned" do
    item = @calendar.calendar_items.create!(title: "Prep", starts_at: Time.current)

    assert_equal "planned", item.status
  end

  test "can assign team members" do
    member = users(:one)
    item = @calendar.calendar_items.create!(
      title: "Vendor Call",
      starts_at: Time.current,
      team_members: [member]
    )

    assert_includes item.team_members, member
  end

  test "clears tags when none selected" do
    tag = @calendar.event_calendar_tags.create!(name: "Milestones")
    item = @calendar.calendar_items.create!(title: "Tag Test", starts_at: Time.current)
    item.event_calendar_tag_ids = [tag.id]
    item.save!

    item.event_calendar_tag_ids = []
    item.save!

    assert_empty item.reload.event_calendar_tag_ids
  end
end
