require "test_helper"

module RosAgent
  module Schemas
    class QuestionBatchSchemaTest < ActiveSupport::TestCase
      test "accepts a valid question batch payload" do
        payload = {
          "state" => "needs_input",
          "summary" => "A few planning choices will materially change the ROS.",
          "questions" => [
            {
              "key" => "date_mapping",
              "label" => "Date Mapping",
              "question" => "Should source Saturday map to the wedding date?",
              "why_it_matters" => "It shifts every date in the timeline.",
              "required" => true,
              "answer_type" => "single_choice",
              "options" => [
                {
                  "value" => "map_saturday_to_wedding_date",
                  "label" => "Map Saturday",
                  "recommended" => true,
                  "description" => "Use the event date as the Saturday anchor."
                }
              ],
              "freeform_allowed" => true
            }
          ],
          "assumptions" => ["Remove source-specific client names."],
          "source_observations" => ["Source has clear Friday and Saturday sections."],
          "risk_notes" => ["Ceremony anchor is missing from the source."]
        }

        assert_equal payload, QuestionBatchSchema.validate!(payload)
      end

      test "rejects duplicate question keys" do
        payload = {
          "state" => "needs_input",
          "summary" => "Need answers",
          "questions" => [
            question_hash("date_mapping"),
            question_hash("date_mapping")
          ],
          "assumptions" => [],
          "source_observations" => [],
          "risk_notes" => []
        }

        error = assert_raises(ArgumentError) { QuestionBatchSchema.validate!(payload) }

        assert_includes error.message, "duplicate"
      end

      test "rejects invalid answer types and options without a recommended answer" do
        payload = {
          "state" => "needs_input",
          "summary" => "Need answers",
          "questions" => [
            question_hash("date_mapping").merge(
              "answer_type" => "unknown",
              "options" => [
                {
                  "value" => "map",
                  "label" => "Map it",
                  "description" => "No recommended flag here."
                }
              ]
            )
          ],
          "assumptions" => [],
          "source_observations" => [],
          "risk_notes" => []
        }

        error = assert_raises(ArgumentError) { QuestionBatchSchema.validate!(payload) }

        assert_includes error.message, "answer_type"
        assert_includes error.message, "recommended"
      end

      private

      def question_hash(key)
        {
          "key" => key,
          "label" => "Date Mapping",
          "question" => "Should source Saturday map to the wedding date?",
          "why_it_matters" => "It shifts every date in the timeline.",
          "required" => true,
          "answer_type" => "single_choice",
          "options" => [
            {
              "value" => "map_saturday_to_wedding_date",
              "label" => "Map Saturday",
              "recommended" => true,
              "description" => "Use the event date as the Saturday anchor."
            }
          ],
          "freeform_allowed" => true
        }
      end
    end
  end
end
