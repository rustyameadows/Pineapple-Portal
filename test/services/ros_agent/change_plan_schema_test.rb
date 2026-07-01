require "test_helper"

module RosAgent
  module Schemas
    class ChangePlanSchemaTest < ActiveSupport::TestCase
      test "accepts a valid change plan payload" do
        payload = {
          "state" => "ready_for_review",
          "summary" => "Create a production-heavy wedding day ROS draft.",
          "assumptions" => ["Saturday maps to the event date."],
          "operations" => [
            {
              "operation_id" => "op_1",
              "operation_type" => "create_item",
              "summary" => "Create crew call row.",
              "risk_level" => "low",
              "source_refs" => [{ "artifact" => "millar_sample.csv", "locator" => "Saturday row 4" }],
              "item_attributes" => {
                "title" => "Crew Call",
                "starts_at" => "2025-10-01T08:00:00Z"
              },
              "reasoning_summary" => "This preserves the source setup structure."
            }
          ],
          "warnings" => ["Headliner details were converted to placeholders."],
          "review_highlights" => ["Please confirm ceremony anchors before apply."]
        }

        assert_equal payload, ChangePlanSchema.validate!(payload)
      end

      test "rejects duplicate operation ids and unknown operation types" do
        payload = {
          "state" => "ready_for_review",
          "summary" => "Plan summary",
          "assumptions" => [],
          "operations" => [
            invalid_operation.merge("operation_id" => "op_1", "operation_type" => "unknown"),
            invalid_operation.merge("operation_id" => "op_1")
          ],
          "warnings" => [],
          "review_highlights" => []
        }

        error = assert_raises(ArgumentError) { ChangePlanSchema.validate!(payload) }

        assert_includes error.message, "operation_type"
        assert_includes error.message, "duplicate"
      end

      test "rejects invalid risk levels and missing summaries" do
        payload = {
          "state" => "ready_for_review",
          "summary" => " ",
          "assumptions" => [],
          "operations" => [
            invalid_operation.merge("risk_level" => "critical")
          ],
          "warnings" => [],
          "review_highlights" => []
        }

        error = assert_raises(ArgumentError) { ChangePlanSchema.validate!(payload) }

        assert_includes error.message, "summary"
        assert_includes error.message, "risk_level"
      end

      private

      def invalid_operation
        {
          "operation_id" => "op_1",
          "operation_type" => "create_item",
          "summary" => "Create row",
          "risk_level" => "low",
          "source_refs" => [],
          "item_attributes" => { "title" => "Crew Call" }
        }
      end
    end
  end
end
