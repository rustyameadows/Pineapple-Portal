require "set"

module Calendars
  class CascadeScheduler
    CascadeResult = Struct.new(:updated_item_ids, :skipped_locked_ids, keyword_init: true)

    def initialize(event_calendar)
      @event_calendar = event_calendar
      @memoized_times = {}
      @updated_ids = []
      @skipped_locked_ids = []
    end

    def call
      ActiveRecord::Base.transaction do
        items.each do |item|
          if item.locked?
            @skipped_locked_ids << item.id if item.id
            next
          end

          new_start = compute_start_time(item)
          next if new_start.blank?
          next if item.starts_at&.to_i == new_start.to_i

          item.update_columns(starts_at: new_start) # rubocop:disable Rails/SkipsModelValidations
          @updated_ids << item.id if item.id
        end
      end

      CascadeResult.new(
        updated_item_ids: updated_ids,
        skipped_locked_ids: skipped_locked_ids
      )
    end

    private

    attr_reader :event_calendar, :memoized_times, :updated_ids, :skipped_locked_ids

    def items
      @items ||= event_calendar.calendar_items.includes(:relative_anchor)
    end

    def compute_start_time(item, stack = Set.new)
      cache_key = item.id || item.object_id
      return memoized_times[cache_key] if memoized_times.key?(cache_key)

      if item.absolute?
        memoized_times[cache_key] = item.starts_at
        return memoized_times[cache_key]
      end

      if item.locked? && item.starts_at
        memoized_times[cache_key] = item.starts_at
        return memoized_times[cache_key]
      end

      raise CircularDependencyError, item if stack.include?(cache_key)
      stack.add(cache_key)

      anchor = item.relative_anchor
      return nil unless anchor

      anchor_start = compute_start_time(anchor, stack)
      return nil unless anchor_start

      base_time = reference_point_for(item, anchor, anchor_start)
      return nil unless base_time

      offset_minutes = item.relative_offset_minutes.to_i
      offset_minutes *= -1 if item.relative_before?
      new_time = base_time + offset_minutes.minutes

      memoized_times[cache_key] = new_time
      new_time
    ensure
      stack.delete(cache_key)
    end

    class CircularDependencyError < StandardError; end

    def reference_point_for(item, anchor, anchor_start)
      return anchor_start unless item.relative_to_anchor_end?

      anchor_end = anchor_start
      if anchor.duration_minutes.present?
        anchor_end += anchor.duration_minutes.to_i.minutes
      end

      anchor_end
    end
  end
end
