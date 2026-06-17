module Calendars
  module Commands
    class ConvertToRelative
      Result = Struct.new(:success, :message, :item, :summary, keyword_init: true) do
        def success?
          success
        end
      end

      def initialize(calendar:)
        @calendar = calendar
      end

      def call(target_item_id:, anchor_item_id:, anchor_point: "start")
        target = calendar.calendar_items.find_by(id: target_item_id)
        anchor = calendar.calendar_items.find_by(id: anchor_item_id)
        return failure("Choose two calendar items.") unless target && anchor
        return failure("Choose two different calendar items.") if target.id == anchor.id

        normalized_anchor_point = normalize_anchor_point(anchor_point)
        target_start = target.effective_starts_at
        anchor_time = anchor_time_for(anchor, normalized_anchor_point)

        return failure("#{target.title} does not have a scheduled start time.") unless target_start
        return failure("#{anchor.title} does not have a scheduled time.") unless anchor_time

        signed_offset_minutes = ((target_start - anchor_time) / 60).round
        amount = Calendars::TimeAmount.from_minutes(signed_offset_minutes.abs)

        target.assign_attributes(
          starts_at: target_start,
          relative_anchor: anchor,
          relative_offset_minutes: amount.total_minutes,
          relative_offset_display_value: amount.value,
          relative_offset_display_unit: amount.unit,
          relative_offset_display_hours: amount.hours,
          relative_offset_display_minutes: amount.minutes,
          relative_before: signed_offset_minutes.negative?,
          relative_to_anchor_end: normalized_anchor_point == "end"
        )

        return failure(target.errors.full_messages.to_sentence.presence || "Relative timing could not be updated.") unless target.save

        Calendars::CascadeScheduler.new(calendar).call
        success(target:, summary: summary_for(target, anchor, amount, signed_offset_minutes, normalized_anchor_point))
      end

      private

      attr_reader :calendar

      def normalize_anchor_point(anchor_point)
        anchor_point.to_s == "end" ? "end" : "start"
      end

      def anchor_time_for(anchor, anchor_point)
        return anchor.effective_starts_at unless anchor_point == "end"

        anchor.effective_ends_at || anchor.effective_starts_at
      end

      def summary_for(target, anchor, amount, signed_offset_minutes, anchor_point)
        anchor_point_label = anchor_point == "end" ? "ends" : "starts"
        return "#{target.title} starts when #{anchor.title} #{anchor_point_label}" if amount.total_minutes.to_i.zero?

        direction = signed_offset_minutes.negative? ? "before" : "after"
        "#{target.title} starts #{amount.label} #{direction} #{anchor.title} #{anchor_point_label}"
      end

      def success(target:, summary:)
        Result.new(success: true, message: "Relative timing updated.", item: target, summary:)
      end

      def failure(message)
        Result.new(success: false, message:)
      end
    end
  end
end
