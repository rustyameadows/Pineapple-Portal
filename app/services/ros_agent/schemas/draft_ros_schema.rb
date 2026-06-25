module RosAgent
  module Schemas
    class DraftRosSchema
      CONFIDENCE_VALUES = %w[low medium high].freeze
      DETAIL_FIELDS = %w[notes location vendor_handling staff_handling tags].freeze

      def self.json_schema
        {
          type: "object",
          additionalProperties: false,
          required: %w[target_event_summary date_mapping draft_items assumptions review_flags refinement_notes source_references],
          properties: {}
        }
      end

      def self.validate!(payload)
        SchemaValidator.require_object!(payload, %w[target_event_summary date_mapping draft_items assumptions review_flags refinement_notes source_references])
        SchemaValidator.require_present!(payload, "target_event_summary")
        SchemaValidator.require_array!(payload, "draft_items")

        Array(payload["draft_items"]).each_with_index do |item, index|
          raise ArgumentError, "draft_items[#{index}].title is required" if item["title"].blank?
          SchemaValidator.require_array!(item, "details")

          confidence = item["confidence"]
          unless confidence.blank? || CONFIDENCE_VALUES.include?(confidence)
            raise ArgumentError, "draft_items[#{index}].confidence must be one of #{CONFIDENCE_VALUES.join(', ')}"
          end

          Array(item["details"]).each_with_index do |detail, detail_index|
            unless detail.is_a?(Hash)
              raise ArgumentError, "draft_items[#{index}].details[#{detail_index}] must be an object"
            end

            unless DETAIL_FIELDS.include?(detail["field"])
              raise ArgumentError, "draft_items[#{index}].details[#{detail_index}].field must be one of #{DETAIL_FIELDS.join(', ')}"
            end

            if detail["value"].blank?
              raise ArgumentError, "draft_items[#{index}].details[#{detail_index}].value is required"
            end

            SchemaValidator.require_array!(detail, "source_refs")
          end
        end
        payload
      end
    end
  end
end
