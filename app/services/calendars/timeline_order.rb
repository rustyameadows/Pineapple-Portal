module Calendars
  class TimelineOrder
    def self.sort(items, timezone:)
      new(timezone).sort(items)
    end

    def self.start_minute(item, timezone:)
      new(timezone).start_minute(item)
    end

    def initialize(timezone)
      @zone = timezone.is_a?(ActiveSupport::TimeZone) ? timezone : ActiveSupport::TimeZone[timezone]
      @zone ||= Time.zone
    end

    def sort(items)
      Array(items).sort_by do |item|
        [
          start_minute(item) || far_future,
          item.position.to_i,
          item.title.to_s.downcase,
          item.id.to_i
        ]
      end
    end

    def start_minute(item)
      start_time = item.effective_starts_at
      return unless start_time

      start_time.in_time_zone(zone).change(sec: 0, usec: 0)
    end

    private

    attr_reader :zone

    def far_future
      @far_future ||= zone.local(9999, 12, 31)
    end
  end
end
