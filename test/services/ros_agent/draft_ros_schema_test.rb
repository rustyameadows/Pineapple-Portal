require "test_helper"

module RosAgent
  module Schemas
    class DraftRosSchemaTest < ActiveSupport::TestCase
      test "accepts a valid draft ROS payload" do
        payload = {
          "target_event_summary" => "Wedding weekend with an entertainment-heavy Saturday.",
          "date_mapping" => {
            "source_days" => [
              { "source_label" => "Friday, June 13", "target_date" => "2025-09-30" },
              { "source_label" => "Saturday, June 14", "target_date" => "2025-10-01" }
            ]
          },
          "draft_days" => [
            { "label" => "Day Before", "date" => "2025-09-30" },
            { "label" => "Wedding Day", "date" => "2025-10-01" }
          ],
          "draft_items" => [
            {
              "title" => "Crew Call",
              "day_label" => "Wedding Day",
              "timing" => { "kind" => "absolute", "starts_at" => "2025-10-01T08:00:00Z" },
              "duration_minutes" => 60,
              "notes" => "General production setup.",
              "location" => "Grand Ballroom",
              "vendor_handling" => "placeholder",
              "staff_handling" => "map_to_event_team",
              "tags" => ["Production"],
              "confidence" => "high",
              "planner_review_needed" => false,
              "source_refs" => [{ "artifact" => "millar_sample.csv", "locator" => "Saturday row 4" }]
            }
          ],
          "assumptions" => ["Use the event date as the Saturday anchor."],
          "review_flags" => ["Need planner review for headliner placeholders."],
          "refinement_notes" => ["Initial draft generated from source understanding."],
          "source_references" => [{ "artifact" => "millar_sample.csv", "locator" => "Saturday rows" }]
        }

        assert_equal payload, DraftRosSchema.validate!(payload)
      end

      test "rejects a payload without draft days" do
        error = assert_raises(ArgumentError) do
          DraftRosSchema.validate!(
            "target_event_summary" => "Wedding summary",
            "date_mapping" => { "source_days" => [] },
            "draft_days" => [],
            "draft_items" => [],
            "assumptions" => [],
            "review_flags" => [],
            "refinement_notes" => [],
            "source_references" => []
          )
        end

        assert_includes error.message, "draft_days"
      end

      test "rejects draft items without a title" do
        error = assert_raises(ArgumentError) do
          DraftRosSchema.validate!(
            "target_event_summary" => "Wedding summary",
            "date_mapping" => { "source_days" => [] },
            "draft_days" => [{ "label" => "Wedding Day", "date" => "2025-10-01" }],
            "draft_items" => [
              {
                "title" => " ",
                "day_label" => "Wedding Day",
                "timing" => { "kind" => "absolute", "starts_at" => "2025-10-01T08:00:00Z" },
                "confidence" => "high",
                "planner_review_needed" => false,
                "source_refs" => []
              }
            ],
            "assumptions" => [],
            "review_flags" => [],
            "refinement_notes" => [],
            "source_references" => []
          )
        end

        assert_includes error.message, "draft_items[0].title"
      end
    end
  end
end
