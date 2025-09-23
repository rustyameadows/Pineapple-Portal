require "set"

class CalendarItem < ApplicationRecord
  attr_accessor :all_day_mode, :all_day_date

  belongs_to :event_calendar
  belongs_to :relative_anchor, class_name: "CalendarItem", optional: true

  has_many :dependent_items,
           class_name: "CalendarItem",
           foreign_key: :relative_anchor_id,
           dependent: :nullify,
           inverse_of: :relative_anchor

  has_many :calendar_item_tags, dependent: :destroy
  has_many :event_calendar_tags, through: :calendar_item_tags

  validates :title, presence: true
  validates :duration_minutes, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validates :relative_offset_minutes, presence: true
  validate :relative_anchor_same_calendar
  validate :prevent_circular_dependency

  before_validation :default_relative_offset
  before_save :sync_tag_summary

  scope :ordered, -> { order(:starts_at, :position, :id) }
  scope :with_start, -> { where.not(starts_at: nil) }

  def starts_at=(value)
    super(parse_time_in_calendar_zone(value))
  end

  def absolute?
    relative_anchor_id.blank?
  end

  def relative?
    !absolute?
  end

  def effective_starts_at(visited = Set.new)
    return starts_at if absolute?
    return starts_at if locked? && starts_at.present?

    cache_key = object_id
    return nil if visited.include?(cache_key)

    visited.add(cache_key)

    anchor = relative_anchor
    return nil unless anchor

    anchor_start = anchor.effective_starts_at(visited)
    return nil unless anchor_start

    base_time = if relative_to_anchor_end?
                  anchor.effective_ends_at(visited) || anchor_start
                else
                  anchor_start
                end

    offset_minutes = relative_offset_minutes.to_i
    offset_minutes *= -1 if relative_before?
    base_time + offset_minutes.minutes
  ensure
    visited.delete(cache_key)
  end

  def locked?
    locked
  end

  def effective_ends_at(visited = Set.new)
    return unless duration_minutes.present?

    start_time = effective_starts_at(visited)
    return unless start_time

    start_time + duration_minutes.to_i.minutes
  end

  def refresh_tag_summary!
    update_column(:tag_summary, event_calendar_tags.pluck(:name)) # rubocop:disable Rails/SkipsModelValidations
  end

  def all_day?
    explicit_toggle = ActiveModel::Type::Boolean.new.cast(all_day_mode)
    return explicit_toggle unless all_day_mode.nil?

    start_time = starts_at&.in_time_zone(event_calendar&.timezone || Time.zone)
    start_time&.strftime("%H:%M") == "00:00"
  end

  private

  def default_relative_offset
    self.relative_offset_minutes ||= 0
  end

  def relative_anchor_same_calendar
    return if relative_anchor.blank?

    if relative_anchor_id == id
      errors.add(:relative_anchor_id, "cannot reference itself")
    elsif relative_anchor.event_calendar_id != event_calendar_id
      errors.add(:relative_anchor_id, "must reference an item on the same calendar")
    end
  end

  def prevent_circular_dependency
    return unless relative_anchor.present?

    graph = Calendars::DependencyGraph.new(self)
    errors.add(:relative_anchor_id, "creates a circular dependency") if graph.circular?
  end

  def sync_tag_summary
    self.tag_summary = event_calendar_tags.pluck(:name)
  end

  def parse_time_in_calendar_zone(value)
    return value if value.blank?
    return value unless value.is_a?(String)

    timezone = event_calendar&.timezone
    return value if timezone.blank?

    Time.use_zone(timezone) do
      target = if ActiveModel::Type::Boolean.new.cast(all_day_mode)
                 date_value = all_day_date.presence || value
                 Time.zone.parse(date_value)&.beginning_of_day
               else
                 Time.zone.parse(value)
               end

      target&.utc
    end
  rescue ArgumentError
    value
  end
end
