require "set"

module Calendars
  module Commands
    class ImportItems
      class InvalidSource < StandardError; end
      class InvalidSelection < StandardError; end

      Result = Struct.new(
        :imported_count,
        :fallback_to_absolute_count,
        :missing_time_count,
        :created_tag_count,
        keyword_init: true
      )

      def initialize(destination_event:, destination_calendar:, source_event:, source_timeline_ref:, selection_mode:, selected_item_ids: [])
        @destination_event = destination_event
        @destination_calendar = destination_calendar
        @source_event = source_event
        @source_timeline_ref = source_timeline_ref.to_s
        @selection_mode = selection_mode.to_s
        @selected_item_ids = Array(selected_item_ids).map(&:to_i).reject(&:zero?)
      end

      def call
        source_calendar = source_event.run_of_show_calendar
        raise InvalidSource, "Selected source event does not have a run of show calendar." unless source_calendar

        timeline_items = resolve_source_items(source_calendar)
        selected_source_items = select_source_items(timeline_items)
        raise InvalidSelection, "No items matched the selected import options." if selected_source_items.empty?

        selected_source_ids = selected_source_items.map(&:id).to_set
        shift_minutes = event_start_shift_minutes
        destination_tag_map = build_destination_tag_map
        next_position = destination_calendar.calendar_items.maximum(:position).to_i
        source_to_imported = {}
        fallback_to_absolute_count = 0
        missing_time_count = 0
        created_tag_count = 0

        ActiveRecord::Base.transaction do
          selected_source_items.each do |source_item|
            next_position += 1
            attrs = build_base_attributes(source_item).merge(position: next_position)

            if preserve_relative_anchor?(source_item, selected_source_ids)
              attrs.merge!(build_relative_attributes(source_item))
            elsif source_item.relative?
              fallback_to_absolute_count += 1
              shifted_effective_start = shift_time(source_item.effective_starts_at, shift_minutes)
              missing_time_count += 1 if shifted_effective_start.nil?
              attrs.merge!(build_fallback_absolute_attributes(shifted_effective_start))
            else
              attrs.merge!(build_absolute_attributes(source_item, shift_minutes))
            end

            source_to_imported[source_item.id] = destination_calendar.calendar_items.create!(attrs)
          end

          selected_source_items.each do |source_item|
            next unless preserve_relative_anchor?(source_item, selected_source_ids)

            imported_item = source_to_imported[source_item.id]
            imported_anchor = source_to_imported[source_item.relative_anchor_id]
            next unless imported_item && imported_anchor

            imported_item.update!(relative_anchor: imported_anchor)
          end

          selected_source_items.each do |source_item|
            imported_item = source_to_imported.fetch(source_item.id)
            tag_result = sync_tags_for_item(
              source_item: source_item,
              imported_item: imported_item,
              destination_tag_map: destination_tag_map
            )
            created_tag_count += tag_result[:created_count]
          end

          Calendars::CascadeScheduler.new(destination_calendar).call
        end

        Result.new(
          imported_count: selected_source_items.size,
          fallback_to_absolute_count: fallback_to_absolute_count,
          missing_time_count: missing_time_count,
          created_tag_count: created_tag_count
        )
      end

      private

      attr_reader :destination_event,
                  :destination_calendar,
                  :source_event,
                  :source_timeline_ref,
                  :selection_mode,
                  :selected_item_ids

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

      def build_absolute_attributes(source_item, shift_minutes)
        {
          starts_at: shift_time(source_item.starts_at, shift_minutes),
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

      def preserve_relative_anchor?(source_item, selected_source_ids)
        source_item.relative? && selected_source_ids.include?(source_item.relative_anchor_id)
      end

      def sync_tags_for_item(source_item:, imported_item:, destination_tag_map:)
        created_count = 0
        destination_tag_ids = source_item.event_calendar_tags.map do |source_tag|
          name = source_tag.name.to_s.strip
          next if name.blank?

          key = name.downcase
          destination_tag = destination_tag_map[key]
          unless destination_tag
            destination_tag = destination_calendar.event_calendar_tags.create!(
              name: name,
              color_token: source_tag.color_token
            )
            destination_tag_map[key] = destination_tag
            created_count += 1
          end
          destination_tag.id
        end.compact.uniq

        imported_item.event_calendar_tag_ids = destination_tag_ids
        { created_count: created_count }
      end

      def build_destination_tag_map
        destination_calendar.event_calendar_tags.each_with_object({}) do |tag, map|
          key = tag.name.to_s.strip.downcase
          next if key.blank?

          map[key] = tag
        end
      end

      def event_start_shift_minutes
        return 0 unless source_event.starts_on.present? && destination_event.starts_on.present?

        (destination_event.starts_on - source_event.starts_on).to_i * 24 * 60
      end

      def shift_time(time_value, shift_minutes)
        return nil if time_value.blank?

        time_value + shift_minutes.minutes
      end
    end
  end
end
