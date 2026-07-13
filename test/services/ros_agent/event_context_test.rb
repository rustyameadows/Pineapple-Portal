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
      assert_equal [
        {
          id: event_vendors(:catering).id,
          global_vendor_id: event_vendors(:catering).global_vendor_id,
          name: "Sunshine Catering",
          vendor_type: "Catering",
          social_handle: "@sunshinecatering"
        },
        {
          id: event_vendors(:lighting).id,
          global_vendor_id: event_vendors(:lighting).global_vendor_id,
          name: "Bright Lights Production",
          vendor_type: "Lighting",
          social_handle: "@brightlights"
        },
        {
          id: event_vendors(:pineapple_one).id,
          global_vendor_id: event_vendors(:pineapple_one).global_vendor_id,
          name: "Pineapple Productions",
          vendor_type: "Planning",
          social_handle: "@pineappleprodc"
        }
      ], payload.fetch(:vendors)
      assert_equal users(:one).id, payload.dig(:team, :planners, 0, :id)
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

    test "serializes global vendor identity and the event type override" do
      vendor = event_vendors(:catering)
      vendor.update_columns(
        name: "Legacy Event Name",
        social_handle: "@legacy-event-handle",
        vendor_type: "Reception Catering"
      )
      vendor.global_vendor.update!(
        name: "Sunshine Hospitality",
        default_social_handle: "sunshinehospitality"
      )

      payload = EventContext.new(events(:one)).as_json
      serialized = payload.fetch(:vendors).find { |entry| entry[:id] == vendor.id }

      assert_equal "Sunshine Hospitality", serialized[:name]
      assert_equal "@sunshinehospitality", serialized[:social_handle]
      assert_equal "Reception Catering", serialized[:vendor_type]
    end
  end
end
