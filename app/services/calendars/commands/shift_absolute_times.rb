module Calendars
  module Commands
    class ShiftAbsoluteTimes
      Result = Struct.new(:affected_ids, :skipped_ids, :offset_minutes, keyword_init: true)

      def initialize(calendar:, scheduler: Calendars::CascadeScheduler)
        @calendar = calendar
        @scheduler_class = scheduler
      end

      def call(item_ids:, offset_minutes:)
        affected = []
        skipped = []

        ActiveRecord::Base.transaction do
          calendar.calendar_items.where(id: item_ids).find_each do |item|
            if item.locked? || item.starts_at.blank?
              skipped << item.id
              next
            end

            item.update_columns(starts_at: item.starts_at + offset_minutes.minutes) # rubocop:disable Rails/SkipsModelValidations
            affected << item.id
          end

          scheduler_class.new(calendar).call
        end

        Result.new(affected_ids: affected, skipped_ids: skipped, offset_minutes: offset_minutes)
      end

      private

      attr_reader :calendar, :scheduler_class
    end
  end
end
