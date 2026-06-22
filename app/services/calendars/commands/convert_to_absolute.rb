module Calendars
  module Commands
    class ConvertToAbsolute
      Result = Struct.new(:success, :message, :item, :summary, keyword_init: true) do
        def success?
          success
        end
      end

      def initialize(calendar:)
        @calendar = calendar
      end

      def call(item_id:)
        item = calendar.calendar_items.find_by(id: item_id)
        return failure("Choose a calendar item.") unless item

        projected_start = item.effective_starts_at
        return failure("#{item.title} does not have a scheduled start time.") unless projected_start

        item.assign_attributes(
          starts_at: projected_start,
          relative_anchor_id: nil,
          relative_offset_minutes: 0,
          relative_offset_display_value: 0,
          relative_offset_display_unit: "days",
          relative_offset_display_hours: 0,
          relative_offset_display_minutes: 0,
          relative_before: false,
          relative_to_anchor_end: false
        )

        return failure(item.errors.full_messages.to_sentence.presence || "Absolute timing could not be set.") unless item.save

        Calendars::CascadeScheduler.new(calendar).call
        success(item:, summary: "#{item.title} starts at #{projected_start}")
      end

      private

      attr_reader :calendar

      def success(item:, summary:)
        Result.new(success: true, message: "Absolute timing set.", item:, summary:)
      end

      def failure(message)
        Result.new(success: false, message:)
      end
    end
  end
end
