require "test_helper"

class CalendarHelperTest < ActionView::TestCase
  include CalendarHelper

  setup do
    @event = events(:one)
    @calendar = event_calendars(:run_of_show)
    @calendar.update!(timezone: "America/New_York")
  end

  test "ros agent draft schedule label shows date-only starts as midnight" do
    entry = {
      "title" => "Production Load-In",
      "timing" => { "starts_at" => "2026-07-12" }
    }

    assert_equal "12:00 AM", ros_agent_draft_schedule_label(entry, @calendar.timezone)
  end

  test "ros agent final plan preview shows date-only starts as midnight with date context" do
    attrs = {
      "title" => "Production Load-In",
      "starts_at" => "2026-07-12"
    }

    assert_equal "Jul 12 • 12:00 AM", ros_agent_preview_when_label(task_for_calendar, {}, attrs)
  end

  test "ros agent final plan preview shows midnight ranges with clock labels" do
    attrs = {
      "title" => "Production Load-In",
      "starts_at" => "2026-07-12",
      "duration_minutes" => 120
    }

    assert_equal "Jul 12 • 12:00 AM – 2:00 AM", ros_agent_preview_when_label(task_for_calendar, {}, attrs)
  end

  test "ros agent final plan preview keeps non-midnight date and clock labels" do
    attrs = {
      "title" => "Lift Delivery",
      "starts_at" => "2026-07-12T09:00:00"
    }

    assert_equal "Jul 12 • 9:00 AM", ros_agent_preview_when_label(task_for_calendar, {}, attrs)
  end

  private

  def task_for_calendar
    Struct.new(:event).new(@event)
  end
end
