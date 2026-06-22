module RosAgent
  module Schemas
    class DraftRosSchema
      CONFIDENCE_VALUES = %w[low medium high].freeze

      def self.json_schema
        {
          type: "object",
          additionalProperties: false,
          required: %w[target_event_summary date_mapping draft_days draft_items assumptions review_flags refinement_notes source_references],
          properties: {}
        }
      end

      def self.validate!(payload)
        SchemaValidator.require_object!(payload, %w[target_event_summary date_mapping draft_days draft_items assumptions review_flags refinement_notes source_references])
        SchemaValidator.require_present!(payload, "target_event_summary")
        SchemaValidator.require_array!(payload, "draft_days", allow_empty: false)
        SchemaValidator.require_array!(payload, "draft_items")

        Array(payload["draft_items"]).each_with_index do |item, index|
          raise ArgumentError, "draft_items[#{index}].title is required" if item["title"].blank?

          confidence = item["confidence"]
          next if confidence.blank? || CONFIDENCE_VALUES.include?(confidence)

          raise ArgumentError, "draft_items[#{index}].confidence must be one of #{CONFIDENCE_VALUES.join(', ')}"
        end
        payload
      end
    end
  end
end
