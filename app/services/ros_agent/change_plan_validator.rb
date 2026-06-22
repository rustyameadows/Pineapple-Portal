module RosAgent
  class ChangePlanValidator
    Result = Data.define(:blocking_errors, :warnings, :high_risk_operation_ids) do
      def valid?
        blocking_errors.empty?
      end

      def as_json(*)
        {
          blocking_errors: blocking_errors,
          warnings: warnings,
          high_risk_operation_ids: high_risk_operation_ids
        }
      end
    end

    EXISTING_ITEM_OPERATIONS = %w[update_item delete_item assign_tags].freeze
    KNOWN_OPERATIONS = %w[create_item update_item delete_item create_tag assign_tags].freeze

    def initialize(task:, calendar:, plan_hash:)
      @task = task
      @calendar = calendar
      @plan_hash = plan_hash || {}
      @blocking_errors = []
      @warnings = []
      @high_risk_operation_ids = []
    end

    def call
      operations.each do |operation|
        validate_common_fields(operation)
        validate_known_operation(operation)
        validate_create_item(operation) if operation_type(operation) == "create_item"
        validate_existing_item(operation) if EXISTING_ITEM_OPERATIONS.include?(operation_type(operation))
        track_high_risk(operation)
      end

      Result.new(
        blocking_errors: blocking_errors,
        warnings: warnings,
        high_risk_operation_ids: high_risk_operation_ids.uniq
      )
    end

    private

    attr_reader :task, :calendar, :plan_hash, :blocking_errors, :warnings, :high_risk_operation_ids

    def operations
      Array(plan_hash["operations"] || plan_hash[:operations])
    end

    def validate_common_fields(operation)
      operation_id = operation_id(operation)
      %w[operation_id operation_type summary risk_level].each do |field|
        value = operation[field] || operation[field.to_sym]
        blocking_errors << "Operation #{operation_id || '(missing id)'} must provide #{field}." if value.blank?
      end
    end

    def validate_known_operation(operation)
      type = operation_type(operation)
      return if type.blank?
      return if KNOWN_OPERATIONS.include?(type)

      blocking_errors << "Operation #{operation_id(operation)} has unknown operation_type #{type}."
    end

    def validate_create_item(operation)
      title = attributes_for(operation)["title"]
      return if title.present?

      blocking_errors << "Operation #{operation_id(operation)} must provide attributes.title for create_item."
    end

    def validate_existing_item(operation)
      return if operation["target_item_operation_id"].present? || operation[:target_item_operation_id].present?

      item_id = operation["target_item_id"] || operation[:target_item_id]
      item = calendar.calendar_items.find_by(id: item_id)
      return if item.present?

      blocking_errors << "Operation #{operation_id(operation)} targets an item outside this run of show calendar."
    end

    def track_high_risk(operation)
      id = operation_id(operation)
      return if id.blank?

      if operation_type(operation) == "delete_item"
        high_risk_operation_ids << id
        warnings << "Operation #{id} deletes an existing item."
      elsif operation["risk_level"].to_s == "high" || operation[:risk_level].to_s == "high"
        high_risk_operation_ids << id
      end
    end

    def operation_id(operation)
      operation["operation_id"] || operation[:operation_id]
    end

    def operation_type(operation)
      operation["operation_type"] || operation[:operation_type]
    end

    def attributes_for(operation)
      (operation["attributes"] || operation[:attributes] || {}).with_indifferent_access
    end
  end
end
