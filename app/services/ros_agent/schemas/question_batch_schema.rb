module RosAgent
  module Schemas
    class QuestionBatchSchema
      ANSWER_TYPES = %w[single_choice multi_choice boolean freeform date time].freeze
      REQUIRED_QUESTION_KEYS = %w[key label question why_it_matters required answer_type options freeform_allowed].freeze
      BOOLEAN_QUESTION_KEYS = %w[required freeform_allowed].freeze

      def self.json_schema
        {
          type: "object",
          additionalProperties: false,
          required: %w[state summary questions assumptions source_observations risk_notes],
          properties: {}
        }
      end

      def self.validate!(payload)
        SchemaValidator.require_object!(payload, %w[state summary questions assumptions source_observations risk_notes])
        raise ArgumentError, "state must be needs_input" unless payload["state"] == "needs_input"

        questions = Array(payload["questions"])
        duplicate_keys = SchemaValidator.duplicate_values(questions.map { |question| question["key"] })
        raise ArgumentError, "duplicate question keys: #{duplicate_keys.join(', ')}" if duplicate_keys.any?

        questions.each_with_index { |question, index| validate_question!(question, index) }
        payload
      end

      def self.validate_question!(question, index)
        errors = []
        REQUIRED_QUESTION_KEYS.each do |key|
          errors << "questions[#{index}].#{key} is required" if missing_required_key?(question, key)
        end

        BOOLEAN_QUESTION_KEYS.each do |key|
          next unless question.key?(key)

          errors << "questions[#{index}].#{key} must be true or false" unless [true, false].include?(question[key])
        end

        unless ANSWER_TYPES.include?(question["answer_type"])
          errors << "questions[#{index}].answer_type must be one of #{ANSWER_TYPES.join(', ')}"
        end

        options = Array(question["options"])
        if options.any? && options.none? { |option| option["recommended"] == true }
          errors << "questions[#{index}].options must include a recommended answer"
        end

        raise ArgumentError, errors.join("; ") if errors.any?
      end

      def self.missing_required_key?(question, key)
        return true unless question.key?(key)
        return false if BOOLEAN_QUESTION_KEYS.include?(key)
        return false if key == "options" && question[key].is_a?(Array)

        question[key].blank?
      end
    end
  end
end
