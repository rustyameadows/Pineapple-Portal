module RosAgent
  module Schemas
    class SourceUnderstandingSchema
      CONFIDENCE_VALUES = %w[low medium high].freeze

      def self.json_schema
        base_schema(
          required: %w[source_title source_kind overall_read inferred_days reusable_patterns source_specific_details uncertainties confidence_notes source_evidence_refs],
          properties: {
            source_title: { type: "string" },
            source_kind: { type: "string" },
            overall_read: { type: "string" },
            inferred_days: { type: "array" },
            reusable_patterns: { type: "array" },
            source_specific_details: { type: "array" },
            uncertainties: { type: "array" },
            confidence_notes: { type: "array" },
            source_evidence_refs: { type: "array" }
          }
        )
      end

      def self.validate!(payload)
        SchemaValidator.require_object!(payload, %w[source_title source_kind overall_read inferred_days reusable_patterns source_specific_details uncertainties confidence_notes source_evidence_refs])
        SchemaValidator.require_present!(payload, "source_title")
        Array(payload["inferred_days"]).each_with_index do |day, index|
          confidence = day["confidence"]
          next if CONFIDENCE_VALUES.include?(confidence)

          raise ArgumentError, "inferred_days[#{index}].confidence must be one of #{CONFIDENCE_VALUES.join(', ')}"
        end
        payload
      end

      def self.base_schema(required:, properties:)
        {
          type: "object",
          additionalProperties: false,
          required: required,
          properties: properties
        }
      end
    end
  end
end
