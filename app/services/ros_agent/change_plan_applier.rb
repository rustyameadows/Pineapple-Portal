module RosAgent
  class ChangePlanApplier
    Result = Data.define(:applied, :errors, :operation_counts) do
      def applied?
        applied
      end
    end

    class ApplyFailed < StandardError; end

    ITEM_ATTRIBUTES = %w[
      title notes starts_at duration_minutes vendor_name location_name
      time_caption transportation_note guest_count additional_team_members
      relative_anchor_id relative_offset_minutes relative_before
      relative_to_anchor_end locked status
    ].freeze
    NON_NULL_ITEM_ATTRIBUTES = %w[
      title relative_offset_minutes relative_before relative_to_anchor_end locked status
    ].freeze

    def initialize(task:, calendar:, plan_hash:)
      @task = task
      @calendar = calendar
      @plan_hash = plan_hash || {}
      @created_items_by_operation_id = {}
      @tags_by_name = {}
      @operation_counts = {
        create_count: 0,
        update_count: 0,
        delete_count: 0,
        create_tag_count: 0,
        assign_tag_count: 0
      }
    end

    def call
      guard_errors = approval_errors
      return Result.new(applied: false, errors: guard_errors, operation_counts: operation_counts) if guard_errors.any?

      validator_result = ChangePlanValidator.new(task: task, calendar: calendar, plan_hash: plan_hash).call
      return Result.new(applied: false, errors: validator_result.blocking_errors, operation_counts: operation_counts) unless validator_result.valid?

      ActiveRecord::Base.transaction do
        operations.each { |operation| apply_operation(operation) }
        Calendars::CascadeScheduler.new(calendar).call
        mark_task_applied!
      end

      Result.new(applied: true, errors: [], operation_counts: operation_counts)
    rescue ActiveRecord::RecordInvalid => e
      Result.new(applied: false, errors: [e.record.errors.full_messages.to_sentence], operation_counts: operation_counts)
    rescue ApplyFailed => e
      Result.new(applied: false, errors: [e.message], operation_counts: operation_counts)
    end

    private

    attr_reader :task, :calendar, :plan_hash, :created_items_by_operation_id, :tags_by_name, :operation_counts

    def approval_errors
      errors = []
      errors << "Task must be approved before applying a ROS change plan." unless task_status == "approved"
      if task.respond_to?(:approved_plan_version) && task.respond_to?(:current_plan_version) &&
         task.approved_plan_version != task.current_plan_version
        errors << "Approved plan version must match the current plan version."
      end
      if task.respond_to?(:validation_blocking_errors) && task.validation_blocking_errors.any?
        errors << "Blocking validation errors must be resolved before applying a ROS change plan."
      end
      if task.respond_to?(:high_risk_plan?) && task.high_risk_plan? &&
         task.respond_to?(:high_risk_acknowledged?) && !task.high_risk_acknowledged?
        errors << "High-risk operations must be acknowledged before applying a ROS change plan."
      end
      errors
    end

    def operations
      Array(plan_hash["operations"] || plan_hash[:operations])
    end

    def apply_operation(operation)
      case operation_type(operation)
      when "create_item"
        create_item(operation)
      when "update_item"
        update_item(operation)
      when "delete_item"
        delete_item(operation)
      when "create_tag"
        create_tag(operation)
      when "assign_tags"
        assign_tags(operation)
      else
        raise ApplyFailed, "Unsupported operation type #{operation_type(operation)}."
      end
    end

    def create_item(operation)
      item = calendar.calendar_items.create!(item_attributes(operation).merge(position: next_position))
      created_items_by_operation_id[operation_id(operation)] = item
      operation_counts[:create_count] += 1
      apply_tags_to_item(item, operation)
    end

    def update_item(operation)
      item = target_item(operation)
      item.update!(item_attributes(operation))
      operation_counts[:update_count] += 1
    end

    def delete_item(operation)
      target_item(operation).destroy!
      operation_counts[:delete_count] += 1
    end

    def create_tag(operation)
      name = (operation["name"] || operation[:name]).to_s.strip
      raise ApplyFailed, "Tag name is required." if name.blank?

      tag = calendar.event_calendar_tags.create!(
        name: name,
        color_token: operation["color_token"] || operation[:color_token]
      )
      tags_by_name[name.downcase] = tag
      operation_counts[:create_tag_count] += 1
    end

    def assign_tags(operation)
      item = target_item(operation)
      apply_tags_to_item(item, operation)
    end

    def apply_tags_to_item(item, operation)
      tag_ids = tag_ids_for(operation)
      return if tag_ids.blank?

      item.update!(event_calendar_tag_ids: (item.event_calendar_tag_ids + tag_ids).uniq)
      operation_counts[:assign_tag_count] += 1
    end

    def tag_ids_for(operation)
      tag_ids = Array(operation["tag_ids"] || operation[:tag_ids]).map(&:to_i).reject(&:zero?)
      tag_ids += Array(operation["tag_names"] || operation[:tag_names]).filter_map { |name| tag_for_name(name)&.id }
      tag_ids.uniq
    end

    def tag_for_name(raw_name)
      name = raw_name.to_s.strip
      return if name.blank?

      tags_by_name[name.downcase] ||= calendar.event_calendar_tags.where("LOWER(name) = ?", name.downcase).first
    end

    def target_item(operation)
      if operation["target_item_operation_id"].present? || operation[:target_item_operation_id].present?
        item = created_items_by_operation_id[operation["target_item_operation_id"] || operation[:target_item_operation_id]]
        raise ApplyFailed, "Operation #{operation_id(operation)} references an unknown created item." unless item

        return item
      end

      calendar.calendar_items.find(operation["target_item_id"] || operation[:target_item_id])
    end

    def item_attributes(operation)
      attrs = attributes_for(operation).slice(*ITEM_ATTRIBUTES)
      NON_NULL_ITEM_ATTRIBUTES.each { |key| attrs.delete(key) if attrs[key].nil? }
      if attrs.key?("starts_at") && attrs["starts_at"].present?
        attrs["starts_at"] = Time.zone.parse(attrs["starts_at"].to_s)
      end
      attrs
    end

    def attributes_for(operation)
      (operation["attributes"] || operation[:attributes] ||
        operation["item_attributes"] || operation[:item_attributes] || {}).with_indifferent_access
    end

    def next_position
      calendar.calendar_items.maximum(:position).to_i + operation_counts[:create_count] + 1
    end

    def mark_task_applied!
      applied_at = Time.current.to_time
      task.status = "applied" if task.respond_to?(:status=)
      task.applied_at = applied_at if task.respond_to?(:applied_at=)
      task.applied_operation_counts = operation_counts if task.respond_to?(:applied_operation_counts=)
      if task.respond_to?(:save!) && task.is_a?(ApplicationRecord)
        task.save!
      end
      if task.respond_to?(:append_event!)
        task.append_event!(
          event_type: "applied",
          message: "Applied ROS agent change plan.",
          payload: { operation_counts: operation_counts }
        )
      end
    end

    def operation_id(operation)
      operation["operation_id"] || operation[:operation_id]
    end

    def operation_type(operation)
      operation["operation_type"] || operation[:operation_type]
    end

    def task_status
      task.respond_to?(:status) ? task.status.to_s : nil
    end
  end
end
