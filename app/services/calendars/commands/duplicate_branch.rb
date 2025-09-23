module Calendars
  module Commands
    class DuplicateBranch
      Result = Struct.new(:mapping, keyword_init: true)

      def initialize(calendar:)
        @calendar = calendar
      end

      def call(root_item_id:, attach_to_anchor_id: nil)
        root_item = calendar.calendar_items.includes(:event_calendar_tags, dependent_items: :event_calendar_tags).find(root_item_id)
        anchor_override = anchor_for_duplicate(root_item, attach_to_anchor_id)

        mapping = {}

        ActiveRecord::Base.transaction do
          duplicate_recursive(root_item, mapping, anchor_override: anchor_override)
          Calendars::CascadeScheduler.new(calendar).call
        end

        Result.new(mapping: mapping)
      end

      private

      attr_reader :calendar

      def duplicate_recursive(item, mapping, anchor_override: nil)
        new_item = calendar.calendar_items.create!(
          title: item.title,
          notes: item.notes,
          duration_minutes: item.duration_minutes,
          starts_at: item.starts_at,
          relative_offset_minutes: item.relative_offset_minutes,
          relative_before: item.relative_before,
          locked: item.locked,
          position: next_position
        )

        mapping[item.id] = new_item

        new_anchor = determine_anchor(item, mapping, anchor_override)
        new_item.update!(relative_anchor: new_anchor) if new_anchor

        item.event_calendar_tags.each do |tag|
          CalendarItemTag.create!(calendar_item: new_item, event_calendar_tag: tag)
        end

        item.dependent_items.each do |child|
          duplicate_recursive(child, mapping)
        end
      end

      def determine_anchor(item, mapping, anchor_override)
        return anchor_override if anchor_override

        return unless item.relative_anchor_id

        mapping[item.relative_anchor_id] || item.relative_anchor
      end

      def anchor_for_duplicate(root_item, attach_to_anchor_id)
        return nil unless attach_to_anchor_id

        calendar.calendar_items.find_by(id: attach_to_anchor_id)
      end

      def next_position
        @position_cursor ||= calendar.calendar_items.maximum(:position).to_i
        @position_cursor += 1
      end
    end
  end
end
