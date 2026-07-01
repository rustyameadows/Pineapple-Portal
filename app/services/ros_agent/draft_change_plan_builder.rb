module RosAgent
  class DraftChangePlanBuilder
    DETAIL_ATTRIBUTE_MAP = {
      "notes" => "notes",
      "location" => "location_name",
      "vendor_handling" => "vendor_name",
      "staff_handling" => "additional_team_members"
    }.freeze

    def initialize(task:, calendar:)
      @task = task
      @calendar = calendar
    end

    def call
      {
        "state" => "ready_for_review",
        "summary" => summary,
        "assumptions" => string_array(draft["assumptions"]),
        "operations" => draft_items.each_with_index.map { |item, index| operation_for(item, index) },
        "warnings" => string_array(draft["review_flags"]) + string_array(draft["refinement_notes"]),
        "review_highlights" => review_highlights
      }
    end

    private

    attr_reader :task, :calendar

    def draft
      @draft ||= (task.draft_ros_json || {}).with_indifferent_access
    end

    def draft_items
      Array(draft["draft_items"])
    end

    def summary
      item_count = draft_items.length
      "Create #{item_count} #{'ROS item'.pluralize(item_count)} from the reviewed draft."
    end

    def review_highlights
      string_array([draft["target_event_summary"]]).presence || ["Reviewed draft ROS is ready for approval."]
    end

    def operation_for(item, index)
      item = item.with_indifferent_access
      {
        "operation_id" => format("create_%03d", index + 1),
        "operation_type" => "create_item",
        "summary" => "Create #{item['title']}",
        "risk_level" => "low",
        "source_refs" => source_refs_for(item),
        "item_attributes" => item_attributes_for(item),
        "target_item_id" => nil,
        "target_item_operation_id" => nil,
        "tag_ids" => [],
        "tag_names" => tag_names_for(item),
        "name" => nil,
        "color_token" => nil,
        "reasoning_summary" => "Promoted from reviewed draft item #{index + 1}."
      }
    end

    def item_attributes_for(item)
      details = grouped_details(item)
      attrs = {
        "title" => item["title"],
        "starts_at" => item.dig("timing", "starts_at").presence || item["starts_at"].presence,
        "duration_minutes" => item["duration_minutes"],
        "time_caption" => item["time_caption"].presence || item["time_label"].presence
      }

      DETAIL_ATTRIBUTE_MAP.each do |detail_field, attribute_name|
        value = detail_value(details[detail_field])
        attrs[attribute_name] = value if value.present?
      end

      attrs.compact
    end

    def grouped_details(item)
      Array(item["details"]).each_with_object(Hash.new { |hash, key| hash[key] = [] }) do |detail, grouped|
        detail = detail.with_indifferent_access
        grouped[detail["field"]] << detail["value"]
      end
    end

    def detail_value(values)
      string_array(values).join("\n").presence
    end

    def tag_names_for(item)
      details = grouped_details(item)
      string_array(details["tags"]).flat_map { |value| value.split(/[,\n;|]/) }.map(&:strip).reject(&:blank?).uniq
    end

    def source_refs_for(item)
      refs = Array(item["source_refs"])
      refs += Array(item["details"]).flat_map { |detail| Array(detail["source_refs"] || detail[:source_refs]) }
      refs.map { |ref| ref.to_h.stringify_keys }.uniq
    end

    def string_array(values)
      Array(values).map { |value| value.to_s.strip }.reject(&:blank?)
    end
  end
end
