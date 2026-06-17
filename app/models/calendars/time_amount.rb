require "bigdecimal"

module Calendars
  class TimeAmount
    MAJOR_UNITS = {
      "days" => 60 * 24,
      "weeks" => 60 * 24 * 7,
      "months" => 60 * 24 * 30
    }.freeze

    DEFAULT_UNIT = "days"
    UNIT_OPTIONS = [
      ["Days", "days"],
      ["Weeks", "weeks"],
      ["Months", "months"]
    ].freeze

    attr_reader :value, :unit, :hours, :minutes, :total_minutes

    def self.from_display(value:, unit:, hours:, minutes:, nullable: false)
      if nullable && [value, hours, minutes].all? { |field| field.to_s.strip.blank? }
        return new(value: nil, unit: nil, hours: nil, minutes: nil, total_minutes: nil)
      end

      normalized_unit = normalize_unit(unit)
      total_minutes = minutes_from_parts(
        value: value,
        unit: normalized_unit,
        hours: hours,
        minutes: minutes
      )

      from_minutes(total_minutes, preferred_unit: normalized_unit)
    end

    def self.from_minutes(total_minutes, preferred_unit: nil, nullable: false)
      return new(value: nil, unit: nil, hours: nil, minutes: nil, total_minutes: nil) if total_minutes.nil? && nullable

      total_minutes = total_minutes.to_i.abs
      unit = normalize_unit(preferred_unit.presence || exact_unit_for(total_minutes) || DEFAULT_UNIT)
      multiplier = MAJOR_UNITS.fetch(unit)
      value = total_minutes / multiplier
      remainder = total_minutes % multiplier
      hours = remainder / 60
      minutes = remainder % 60

      new(value:, unit:, hours:, minutes:, total_minutes:)
    end

    def self.from_stored(total_minutes:, value:, unit:, hours:, minutes:, nullable: false)
      return from_minutes(nil, nullable: true) if total_minutes.nil? && nullable

      display_amount = from_display(value:, unit:, hours:, minutes:, nullable:)
      canonical_minutes = total_minutes.to_i.abs
      return display_amount if display_amount.total_minutes == canonical_minutes

      from_minutes(canonical_minutes, nullable:)
    end

    def self.normalize_unit(unit)
      unit = unit.to_s
      MAJOR_UNITS.key?(unit) ? unit : DEFAULT_UNIT
    end

    def self.minutes_from_parts(value:, unit:, hours:, minutes:)
      major_minutes = decimal(value) * MAJOR_UNITS.fetch(unit)
      hour_minutes = decimal(hours) * 60
      minute_minutes = decimal(minutes)

      (major_minutes + hour_minutes + minute_minutes).to_i
    end

    def self.exact_unit_for(total_minutes)
      return DEFAULT_UNIT if total_minutes.zero?

      MAJOR_UNITS.keys.reverse.find do |unit|
        (total_minutes % MAJOR_UNITS.fetch(unit)).zero?
      end
    end

    def self.decimal(value)
      raw = value.to_s.strip
      return BigDecimal("0") if raw.blank?

      BigDecimal(raw)
    rescue ArgumentError
      BigDecimal("0")
    end

    def initialize(value:, unit:, hours:, minutes:, total_minutes:)
      @value = value
      @unit = unit
      @hours = hours
      @minutes = minutes
      @total_minutes = total_minutes
    end

    def null?
      total_minutes.nil?
    end

    def label
      return "" if null?

      parts = []
      parts << "#{value} #{unit_label(value, unit)}" if value.to_i.positive?
      parts << "#{hours} hr" if hours.to_i.positive?
      parts << "#{minutes} min" if minutes.to_i.positive?
      parts.any? ? parts.join(" ") : "0 #{unit}"
    end

    private

    def unit_label(amount, unit)
      amount.to_i == 1 ? unit.singularize : unit
    end
  end
end
