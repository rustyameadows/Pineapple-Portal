require "test_helper"

class EventCalendarTest < ActiveSupport::TestCase
  setup do
    @event = events(:one)
    @calendar = event_calendars(:run_of_show)
  end

  test "requires unique slug per event" do
    duplicate = @event.event_calendars.new(name: @calendar.name, slug: @calendar.slug, timezone: "UTC")

    assert_not duplicate.valid?
    assert_includes duplicate.errors[:slug], "has already been taken"
  end

  test "enforces single master per event" do
    other_master = @event.event_calendars.new(name: "Another Master", timezone: "UTC", kind: EventCalendar::KINDS[:master])

    assert_not other_master.valid?
    assert_includes other_master.errors[:kind], "already has a master calendar"
  end

  test "generates slug from name when missing" do
    calendar = @event.event_calendars.new(name: "Welcome Dinner", timezone: "UTC", kind: EventCalendar::KINDS[:derived])

    calendar.valid?

    assert_equal "welcome-dinner", calendar.slug
  end
end
