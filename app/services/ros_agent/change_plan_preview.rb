module RosAgent
  class ChangePlanPreview
    def initialize(task:, calendar:, plan_hash:)
      @task = task
      @calendar = calendar
      @plan_hash = plan_hash || {}
    end

    def call
      validator_result = ChangePlanValidator.new(task: task, calendar: calendar, plan_hash: plan_hash).call
      {
        create_count: operations.count { |operation| operation_type(operation) == "create_item" },
        update_count: operations.count { |operation| operation_type(operation) == "update_item" },
        delete_count: operations.count { |operation| operation_type(operation) == "delete_item" },
        tag_change_count: operations.count { |operation| %w[create_tag assign_tags].include?(operation_type(operation)) },
        time_change_count: operations.count { |operation| time_change?(operation) },
        assumptions: Array(plan_hash["assumptions"] || plan_hash[:assumptions]),
        warnings: Array(plan_hash["warnings"] || plan_hash[:warnings]) + validator_result.warnings,
        high_risk_operation_ids: validator_result.high_risk_operation_ids,
        grouped_preview_rows: grouped_preview_rows
      }
    end

    private

    attr_reader :task, :calendar, :plan_hash

    def operations
      Array(plan_hash["operations"] || plan_hash[:operations])
    end

    def grouped_preview_rows
      {
        creates: operations.select { |operation| operation_type(operation) == "create_item" }.map { |operation| create_row(operation) },
        updates: operations.select { |operation| operation_type(operation) == "update_item" }.map { |operation| update_row(operation) },
        deletes: operations.select { |operation| operation_type(operation) == "delete_item" }.map { |operation| delete_row(operation) }
      }
    end

    def create_row(operation)
      {
        operation_id: operation_id(operation),
        summary: operation["summary"] || operation[:summary],
        before: nil,
        after: attributes_for(operation).to_h.symbolize_keys
      }
    end

    def update_row(operation)
      item = calendar.calendar_items.find_by(id: operation["target_item_id"] || operation[:target_item_id])
      {
        operation_id: operation_id(operation),
        summary: operation["summary"] || operation[:summary],
        before: item_snapshot(item),
        after: item_snapshot(item).merge(attributes_for(operation).to_h.symbolize_keys)
      }
    end

    def delete_row(operation)
      item = calendar.calendar_items.find_by(id: operation["target_item_id"] || operation[:target_item_id])
      {
        operation_id: operation_id(operation),
        summary: operation["summary"] || operation[:summary],
        before: item_snapshot(item),
        after: nil
      }
    end

    def item_snapshot(item)
      return {} unless item

      {
        id: item.id,
        title: item.title,
        starts_at: item.starts_at&.iso8601,
        duration_minutes: item.duration_minutes,
        vendor_name: item.vendor_name,
        location_name: item.location_name,
        notes: item.notes
      }
    end

    def time_change?(operation)
      attrs = attributes_for(operation)
      attrs.key?("starts_at") || attrs.key?("time_caption") || attrs.key?("relative_anchor_id") || attrs.key?("relative_offset_minutes")
    end

    def operation_id(operation)
      operation["operation_id"] || operation[:operation_id]
    end

    def operation_type(operation)
      operation["operation_type"] || operation[:operation_type]
    end

    def attributes_for(operation)
      (operation["attributes"] || operation[:attributes] ||
        operation["item_attributes"] || operation[:item_attributes] || {}).with_indifferent_access
    end
  end
end
