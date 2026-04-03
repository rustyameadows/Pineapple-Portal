require "set"

module Calendars
  class ImportProjection
    class InvalidSource < StandardError; end
    class InvalidSelection < StandardError; end

    BATCH_TAG_BASE_NAME = "imported".freeze
    BATCH_TAG_COLOR = "slategray".freeze

    ItemPlan = Struct.new(
      :source_item,
      :preserve_relative_anchor,
      :fallback_to_absolute,
      :missing_time,
      :source_effective_start_at,
      :source_effective_end_at,
      :projected_start_at,
      :projected_end_at,
      :import_attributes,
      keyword_init: true
    )

    Result = Struct.new(
      :selected_source_items,
      :item_plans,
      :fallback_to_absolute_count,
      :missing_time_count,
      :anchor_shift_supported,
      :anchor_date_missing,
      :expected_batch_tag_name,
      keyword_init: true
    )

    def self.next_batch_tag_name(destination_source, base_name: BATCH_TAG_BASE_NAME)
      pattern = /\A#{Regexp.escape(base_name)}(?:-(\d+))?\z/i

      names = batch_tag_names(destination_source, base_name)

      highest_suffix = names
        .filter_map do |name|
          match = name.to_s.match(pattern)
          next unless match

          suffix = match[1].to_i
          suffix.positive? ? suffix : 1
        end
        .max

      return base_name if highest_suffix.blank?

      "#{base_name}-#{highest_suffix + 1}"
    end

    def self.batch_tag_names(destination_source, base_name)
      if destination_source.respond_to?(:event_calendar_tags)
        destination_source
          .event_calendar_tags
          .where("lower(name) = :base OR lower(name) LIKE :prefix", base: base_name.downcase, prefix: "#{base_name.downcase}-%")
          .pluck(:name)
      else
        Array(destination_source)
      end
    end

    def initialize(destination_event:, destination_calendar:, source_event:, source_timeline_ref:, selection_mode:, selected_item_ids:, anchor_date:, batch_tag_enabled:)
      @destination_event = destination_event
      @destination_calendar = destination_calendar
      @source_event = source_event
      @source_timeline_ref = source_timeline_ref.to_s
      @selection_mode = selection_mode.to_s
      @selected_item_ids = Array(selected_item_ids).map(&:to_i).reject(&:zero?)
      @anchor_date = normalize_date(anchor_date)
      @batch_tag_enabled = ActiveModel::Type::Boolean.new.cast(batch_tag_enabled)
    end

    def call
      source_calendar = source_event.run_of_show_calendar
      raise InvalidSource, "Selected source event does not have a run of show calendar." unless source_calendar

      timeline_items = resolve_source_items(source_calendar)
      selected_source_items = select_source_items(timeline_items)
      raise InvalidSelection, "No items matched the selected import options." if selected_source_items.empty?

      selected_source_ids = selected_source_items.map(&:id).to_set
      item_plans = selected_source_items.map do |source_item|
        build_item_plan(source_item, selected_source_ids)
      end

      Result.new(
        selected_source_items: selected_source_items,
        item_plans: item_plans,
        fallback_to_absolute_count: item_plans.count(&:fallback_to_absolute),
        missing_time_count: item_plans.count(&:missing_time),
        anchor_shift_supported: anchor_shift_supported?,
        anchor_date_missing: anchor_date_missing?,
        expected_batch_tag_name: batch_tag_enabled ? self.class.next_batch_tag_name(destination_calendar) : nil
      )
    end

    def anchor_shift_supported?
      source_event.starts_on.present?
    end

    def anchor_date_required?
      anchor_shift_supported?
    end

    def anchor_date_missing?
      anchor_date_required? && anchor_date.blank?
    end

    def shift_minutes
      return 0 unless anchor_shift_supported? && anchor_date.present?

      (anchor_date - source_event.starts_on).to_i * 24 * 60
    end

    def shift_time(time_value)
      return nil if time_value.blank?
      return time_value unless anchor_shift_supported? && anchor_date.present?

      time_value + shift_minutes.minutes
    end

    def preserve_relative_anchor?(source_item, selected_source_ids)
      source_item.relative? && selected_source_ids.include?(source_item.relative_anchor_id)
    end

    private

    attr_reader :destination_event,
                :destination_calendar,
                :source_event,
                :source_timeline_ref,
                :selection_mode,
                :selected_item_ids,
                :anchor_date,
                :batch_tag_enabled

    def resolve_source_items(source_calendar)
      case source_timeline_ref
      when "run_of_show"
        source_calendar.calendar_items
                       .includes(:event_calendar_tags, :relative_anchor, :team_members)
                       .ordered
                       .to_a
      else
        view_match = source_timeline_ref.match(/\Aview:(\d+)\z/)
        raise InvalidSource, "Select a valid source timeline." unless view_match

        view = source_calendar.event_calendar_views.find_by(id: view_match[1].to_i)
        raise InvalidSource, "Select a valid source timeline." unless view

        Array(Calendars::ViewFilter.new(calendar: source_calendar, view: view).items)
      end
    end

    def select_source_items(timeline_items)
      case selection_mode
      when "all"
        timeline_items
      when "selected"
        selected_ids = selected_item_ids.to_set
        timeline_items.select { |item| selected_ids.include?(item.id) }
      else
        raise InvalidSelection, "Select how many items to import."
      end
    end

    def build_item_plan(source_item, selected_source_ids)
      source_effective_start_at = source_item.effective_starts_at
      source_effective_end_at = source_item.effective_ends_at
      preserve_relative_anchor = preserve_relative_anchor?(source_item, selected_source_ids)
      missing_time = source_effective_start_at.nil?
      import_attributes = build_base_attributes(source_item)

      if preserve_relative_anchor
        import_attributes.merge!(build_relative_attributes(source_item))
      elsif source_item.relative?
        import_attributes.merge!(build_fallback_absolute_attributes(shift_time(source_effective_start_at)))
      else
        import_attributes.merge!(build_absolute_attributes(source_item))
      end

      ItemPlan.new(
        source_item: source_item,
        preserve_relative_anchor: preserve_relative_anchor,
        fallback_to_absolute: source_item.relative? && !preserve_relative_anchor,
        missing_time: missing_time,
        source_effective_start_at: source_effective_start_at,
        source_effective_end_at: source_effective_end_at,
        projected_start_at: shift_time(source_effective_start_at),
        projected_end_at: shift_time(source_effective_end_at),
        import_attributes: import_attributes
      )
    end

    def normalize_date(value)
      return value if value.is_a?(Date)
      return nil if value.blank?

      Date.iso8601(value.to_s)
    rescue ArgumentError
      nil
    end

    def build_base_attributes(source_item)
      {
        title: source_item.title,
        notes: source_item.notes,
        duration_minutes: source_item.duration_minutes,
        time_caption: source_item.time_caption,
        status: CalendarItem::STATUSES[:planned],
        locked: false,
        vendor_name: nil,
        location_name: nil,
        additional_team_members: nil
      }
    end

    def build_absolute_attributes(source_item)
      {
        starts_at: shift_time(source_item.starts_at),
        relative_anchor_id: nil,
        relative_offset_minutes: 0,
        relative_before: false,
        relative_to_anchor_end: false
      }
    end

    def build_relative_attributes(source_item)
      {
        starts_at: nil,
        relative_anchor_id: nil,
        relative_offset_minutes: source_item.relative_offset_minutes.to_i,
        relative_before: source_item.relative_before?,
        relative_to_anchor_end: source_item.relative_to_anchor_end?
      }
    end

    def build_fallback_absolute_attributes(shifted_effective_start)
      {
        starts_at: shifted_effective_start,
        relative_anchor_id: nil,
        relative_offset_minutes: 0,
        relative_before: false,
        relative_to_anchor_end: false
      }
    end
  end
end
