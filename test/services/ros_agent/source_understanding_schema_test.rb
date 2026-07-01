require "test_helper"

module RosAgent
  module Schemas
    class SourceUnderstandingSchemaTest < ActiveSupport::TestCase
      test "accepts a valid source understanding payload" do
        payload = {
          "source_title" => "Shared MOS_Millar Event - Run of Show.csv",
          "source_kind" => "prior_event_ros",
          "overall_read" => "Entertainment-heavy private event across two days.",
          "inferred_days" => [
            {
              "source_label" => "Friday, June 13",
              "role" => "day_before_event",
              "confidence" => "high",
              "notes" => "Production setup day."
            }
          ],
          "reusable_patterns" => ["crew call", "cocktail hour"],
          "source_specific_details" => [
            {
              "detail" => "Millar",
              "recommended_action" => "remove_or_replace",
              "reason" => "Source client name."
            }
          ],
          "uncertainties" => [
            {
              "key" => "ceremony_missing",
              "question_candidate" => "Should I add ceremony placeholders?"
            }
          ],
          "confidence_notes" => ["Saturday mapping is clear."],
          "source_evidence_refs" => [
            {
              "artifact" => "millar_sample.csv",
              "locator" => "Saturday rows"
            }
          ]
        }

        assert_equal payload, SourceUnderstandingSchema.validate!(payload)
      end

      test "rejects a payload without a source title" do
        error = assert_raises(ArgumentError) do
          SourceUnderstandingSchema.validate!(
            "source_kind" => "prior_event_ros",
            "overall_read" => "Readable",
            "inferred_days" => [],
            "reusable_patterns" => [],
            "source_specific_details" => [],
            "uncertainties" => [],
            "confidence_notes" => [],
            "source_evidence_refs" => []
          )
        end

        assert_includes error.message, "source_title"
      end

      test "rejects invalid confidence values" do
        error = assert_raises(ArgumentError) do
          SourceUnderstandingSchema.validate!(
            "source_title" => "Millar CSV",
            "source_kind" => "prior_event_ros",
            "overall_read" => "Readable",
            "inferred_days" => [
              {
                "source_label" => "Friday",
                "role" => "day_before_event",
                "confidence" => "certain",
                "notes" => "Nope"
              }
            ],
            "reusable_patterns" => [],
            "source_specific_details" => [],
            "uncertainties" => [],
            "confidence_notes" => [],
            "source_evidence_refs" => []
          )
        end

        assert_includes error.message, "confidence"
      end
    end
  end
end
