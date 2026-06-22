require "test_helper"

module RosAgent
  module Schemas
    class AgentTurnSchemaTest < ActiveSupport::TestCase
      test "accepts a full needs-input turn envelope" do
        payload = base_payload.merge(
          "state" => "needs_input",
          "summary" => "Need planner decisions.",
          "questions" => [
            {
              "key" => "date_mapping",
              "label" => "Date Mapping",
              "question" => "Map Saturday to the event date?",
              "why_it_matters" => "This controls the full time shift.",
              "required" => true,
              "answer_type" => "single_choice",
              "options" => [],
              "freeform_allowed" => true
            }
          ]
        )

        assert_equal payload, AgentTurnSchema.validate!(payload)
      end

      test "rejects envelopes that do not match the structured-output contract" do
        error = assert_raises(ArgumentError) do
          AgentTurnSchema.validate!(
            "state" => "draft_ready",
            "summary" => "Missing the required top-level keys."
          )
        end

        assert_includes error.message, "source_understanding"
      end

      test "rejects state-specific missing payloads" do
        error = assert_raises(ArgumentError) do
          AgentTurnSchema.validate!(base_payload.merge("state" => "draft_ready", "summary" => "No draft."))
        end

        assert_includes error.message, "draft_ros"
      end

      private

      def base_payload
        {
          "state" => "needs_input",
          "summary" => "Summary",
          "source_understanding" => nil,
          "recommended_next_state" => nil,
          "questions" => [],
          "draft_ros" => nil,
          "assumptions" => [],
          "source_observations" => [],
          "risk_notes" => [],
          "review_notes" => [],
          "suggested_next_questions" => []
        }
      end
    end
  end
end
