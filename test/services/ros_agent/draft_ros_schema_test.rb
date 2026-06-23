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
              "timing" => { "kind" => "absolute", "starts_at" => "2025-10-01T08:00:00Z" },
              "duration_minutes" => 60,
              "confidence" => "high",
              "source_refs" => [{ "artifact" => "millar_sample.csv", "locator" => "Saturday row 4" }],
              "details" => [
                {
                  "field" => "notes",
                  "value" => "General production setup.",
                  "source_refs" => [{ "artifact" => "millar_sample.csv", "locator" => "Saturday row 4" }]
                },
                {
                  "field" => "location",
                  "value" => "Grand Ballroom",
                  "source_refs" => [{ "artifact" => "millar_sample.csv", "locator" => "Saturday room column" }]
                }
              ]
            }
          ],
          "assumptions" => ["Use the event date as the Saturday anchor."],
          "review_flags" => ["Need planner review for headliner placeholders."],
          "refinement_notes" => ["Initial draft generated from source understanding."],
          "source_references" => [{ "artifact" => "millar_sample.csv", "locator" => "Saturday rows" }]
        }

        assert_equal payload, DraftRosSchema.validate!(payload)
      end

      test "accepts draft items with empty sparse details" do
        payload = base_payload(
          "draft_items" => [
            {
              "title" => "Crew Call",
              "timing" => { "kind" => "absolute", "starts_at" => "2025-10-01T08:00:00Z" },
              "duration_minutes" => 60,
              "confidence" => "high",
              "source_refs" => [],
              "details" => []
            }
          ]
        )

        assert_equal payload, DraftRosSchema.validate!(payload)
      end

      test "rejects draft item details with unknown fields" do
        error = assert_raises(ArgumentError) do
          DraftRosSchema.validate!(
            base_payload(
              "draft_items" => [
                {
                  "title" => "Crew Call",
                  "timing" => { "kind" => "absolute", "starts_at" => "2025-10-01T08:00:00Z" },
                  "duration_minutes" => 60,
                  "confidence" => "high",
                  "source_refs" => [],
                  "details" => [
                    {
                      "field" => "planner_review_needed",
                      "value" => "true",
                      "source_refs" => []
                    }
                  ]
                }
              ]
            )
          )
        end

        assert_includes error.message, "draft_items[0].details[0].field"
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
                "timing" => { "kind" => "absolute", "starts_at" => "2025-10-01T08:00:00Z" },
                "confidence" => "high",
                "source_refs" => [],
                "details" => []
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

      private

      def base_payload(overrides = {})
        {
          "target_event_summary" => "Wedding summary",
          "date_mapping" => { "source_days" => [] },
          "draft_days" => [{ "label" => "Wedding Day", "date" => "2025-10-01" }],
          "draft_items" => [],
          "assumptions" => [],
          "review_flags" => [],
          "refinement_notes" => [],
          "source_references" => []
        }.merge(overrides)
      end
    end
  end
end
