require "test_helper"

module RosAgent
  class EventContextTest < ActiveSupport::TestCase
    test "serializes the current event, ROS items, defaults, tags, views, and team" do
      ceremony = calendar_items(:ceremony)
      ceremony.event_calendar_tags << event_calendar_tags(:day_of) unless ceremony.event_calendar_tags.include?(event_calendar_tags(:day_of))
      ceremony.team_members << users(:one) unless ceremony.team_members.include?(users(:one))

      payload = EventContext.new(events(:one)).as_json

      assert_equal events(:one).id, payload.dig(:event, :id)
      assert_equal "Launch Event", payload.dig(:event, :name)
      assert_equal "UTC", payload.dig(:run_of_show_calendar, :timezone)
      assert_equal "Ada Fixture", payload.dig(:team, :planners, 0, :name)
      assert_equal "Vendor Only", payload.dig(:views, 0, :name)
      assert_includes payload.dig(:tags).map { |tag| tag[:name] }, "Vendor"
      assert_includes payload.dig(:defaults, :tags).map { |tag| tag[:name] }, "Day Of"
      assert_includes payload.dig(:defaults, :views).map { |view| view[:name] }, "Decision Calendar"

      reception_payload = payload.fetch(:current_calendar_items).find { |item| item[:id] == calendar_items(:reception).id }

      assert_equal calendar_items(:ceremony).id, reception_payload.dig(:relative_timing, :anchor_id)
      assert_equal "Ceremony", reception_payload.dig(:relative_timing, :anchor_title)
      assert_equal 120, reception_payload.dig(:relative_timing, :offset_minutes)
      assert_equal false, reception_payload.dig(:relative_timing, :before)
      assert_equal false, reception_payload.dig(:relative_timing, :to_anchor_end)
      assert_includes payload.fetch(:current_calendar_items).map { |item| item[:title] }, "Afterparty"
      refute_includes payload.inspect, "Awards Night"
    end
  end
end
