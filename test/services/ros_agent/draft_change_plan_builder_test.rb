require "test_helper"

module RosAgent
  class DraftChangePlanBuilderTest < ActiveSupport::TestCase
    TaskStub = Struct.new(:event, :draft_ros_json, keyword_init: true)

    setup do
      @event = events(:one)
      @calendar = event_calendars(:run_of_show)
      @task = TaskStub.new(
        event: @event,
        draft_ros_json: {
          "target_event_summary" => "Reviewed ROS for the wedding weekend.",
          "draft_items" => [
            draft_item(
              "Crew Call",
              "2026-08-07T08:00:00-04:00",
              "row 10",
              details: [
                detail("notes", "Production setup."),
                detail("location", "Grand Ballroom"),
                detail("vendor_handling", "DJ TBD"),
                detail("staff_handling", "Assign lead planner."),
                detail("tags", "Production, Music")
              ]
            ),
            draft_item("Crew Call", "2026-08-08T08:00:00-04:00", "row 11"),
            draft_item("Guest Arrival", "2026-08-08T16:00:00-04:00", "row 12", duration_minutes: 30)
          ],
          "assumptions" => ["Saturday source maps to the event date."],
          "review_flags" => ["Confirm DJ placeholder."],
          "refinement_notes" => ["Planner asked to preserve repeated production rows."]
        }
      )
    end

    test "promotes every draft item into a create operation" do
      plan = DraftChangePlanBuilder.new(task: @task, calendar: @calendar).call

      assert_equal "ready_for_review", plan["state"]
      assert_equal 3, plan["operations"].length
      assert_equal ["create_001", "create_002", "create_003"], plan["operations"].map { |operation| operation["operation_id"] }
      assert_equal ["Crew Call", "Crew Call", "Guest Arrival"], plan["operations"].map { |operation| operation.dig("item_attributes", "title") }
      assert_equal ["row 10", "row 11", "row 12"], plan["operations"].map { |operation| operation.dig("source_refs", 0, "locator") }
    end

    test "maps sparse details into item attributes and tag names" do
      plan = DraftChangePlanBuilder.new(task: @task, calendar: @calendar).call
      operation = plan["operations"].first

      assert_equal "Production setup.", operation.dig("item_attributes", "notes")
      assert_equal "Grand Ballroom", operation.dig("item_attributes", "location_name")
      assert_equal "DJ TBD", operation.dig("item_attributes", "vendor_name")
      assert_equal "Assign lead planner.", operation.dig("item_attributes", "additional_team_members")
      assert_equal ["Production", "Music"], operation["tag_names"]
      assert_equal [], operation["tag_ids"]
    end

    test "preserves draft assumptions and review notes as final review text" do
      plan = DraftChangePlanBuilder.new(task: @task, calendar: @calendar).call

      assert_equal ["Saturday source maps to the event date."], plan["assumptions"]
      assert_equal ["Confirm DJ placeholder.", "Planner asked to preserve repeated production rows."], plan["warnings"]
      assert_equal ["Reviewed ROS for the wedding weekend."], plan["review_highlights"]
    end

    test "large drafts produce matching operation counts without placeholders" do
      large_task = TaskStub.new(
        event: @event,
        draft_ros_json: {
          "draft_items" => 25.times.map { |index| draft_item("Production Row #{index + 1}", "2026-07-12", "row #{index + 1}") },
          "assumptions" => [],
          "review_flags" => [],
          "refinement_notes" => []
        }
      )

      plan = DraftChangePlanBuilder.new(task: large_task, calendar: @calendar).call

      assert_equal 25, plan["operations"].length
      assert_empty plan["operations"].select { |operation| operation.dig("item_attributes", "title").to_s.match?(/attached|remaining|bulk/i) }
    end

    private

    def draft_item(title, starts_at, source_row, details: [], duration_minutes: 60)
      {
        "title" => title,
        "timing" => {
          "kind" => "fixed",
          "starts_at" => starts_at,
          "relative_anchor_title" => nil,
          "relative_offset_minutes" => nil
        },
        "duration_minutes" => duration_minutes,
        "confidence" => "high",
        "source_refs" => [
          { "artifact" => "source.csv", "locator" => source_row }
        ],
        "details" => details
      }
    end

    def detail(field, value)
      {
        "field" => field,
        "value" => value,
        "source_refs" => [
          { "artifact" => "source.csv", "locator" => "#{field} column" }
        ]
      }
    end
  end
end
