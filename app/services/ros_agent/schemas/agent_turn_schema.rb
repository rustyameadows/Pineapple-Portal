module RosAgent
  module Schemas
    class AgentTurnSchema
      STATES = %w[source_understood needs_input draft_ready].freeze
      REQUIRED_KEYS = %w[
        state summary source_understanding recommended_next_state questions draft_ros
        assumptions source_observations risk_notes review_notes suggested_next_questions
      ].freeze

      def self.validate!(payload)
        SchemaValidator.require_object!(payload, REQUIRED_KEYS)
        raise ArgumentError, "state must be one of #{STATES.join(', ')}" unless STATES.include?(payload["state"])

        validate_state_payload!(payload)
        payload
      end

      def self.validate_state_payload!(payload)
        case payload["state"]
        when "source_understood"
          raise ArgumentError, "source_understanding is required" unless payload["source_understanding"].is_a?(Hash)
          raise ArgumentError, "recommended_next_state is required" if payload["recommended_next_state"].blank?
        when "needs_input"
          SchemaValidator.require_array!(payload, "questions", allow_empty: false)
        when "draft_ready"
          raise ArgumentError, "draft_ros is required" unless payload["draft_ros"].is_a?(Hash)
        end
      end
    end
  end
end
