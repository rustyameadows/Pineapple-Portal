module RosAgent
  module Schemas
    class ChangePlanSchema
      OPERATION_TYPES = %w[create_item update_item delete_item create_tag assign_tags].freeze
      RISK_LEVELS = %w[low medium high].freeze

      def self.json_schema
        {
          type: "object",
          additionalProperties: false,
          required: %w[state summary assumptions operations warnings review_highlights],
          properties: {}
        }
      end

      def self.validate!(payload)
        SchemaValidator.require_object!(payload, %w[state summary assumptions operations warnings review_highlights])
        errors = []
        errors << "summary is required" if payload["summary"].blank?
        raise ArgumentError, "state must be ready_for_review" unless payload["state"] == "ready_for_review"

        operations = Array(payload["operations"])
        duplicate_ids = SchemaValidator.duplicate_values(operations.map { |operation| operation["operation_id"] })
        errors << "duplicate operation ids: #{duplicate_ids.join(', ')}" if duplicate_ids.any?
        operations.each_with_index { |operation, index| errors.concat(operation_errors(operation, index)) }
        raise ArgumentError, errors.join("; ") if errors.any?

        payload
      end

      def self.operation_errors(operation, index)
        errors = []
        %w[operation_id operation_type summary risk_level source_refs].each do |key|
          errors << "operations[#{index}].#{key} is required" if operation[key].blank?
        end
        errors << "operations[#{index}].operation_type is invalid" unless OPERATION_TYPES.include?(operation["operation_type"])
        errors << "operations[#{index}].risk_level is invalid" unless RISK_LEVELS.include?(operation["risk_level"])
        errors
      end
    end
  end
end
