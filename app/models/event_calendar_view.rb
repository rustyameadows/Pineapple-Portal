class EventCalendarView < ApplicationRecord
  belongs_to :event_calendar

  validates :name, presence: true
  validates :slug, presence: true, uniqueness: { scope: :event_calendar_id }
  validate :validate_calendar_is_master
  validate :validate_tag_filter

  before_validation :generate_slug, if: -> { slug.blank? && name.present? }
  before_validation :normalize_tag_filter

  scope :client_visible, -> { where(client_visible: true) }

  private

  def generate_slug
    base = name.to_s.parameterize
    return self.slug = base if base.blank?

    candidate = base
    suffix = 2
    existing_scope = EventCalendarView.where(event_calendar_id: event_calendar_id)
    existing_scope = existing_scope.where.not(id: id) if id

    while existing_scope.exists?(slug: candidate)
      candidate = "#{base}-#{suffix}"
      suffix += 1
    end

    self.slug = candidate
  end

  def validate_calendar_is_master
    return unless event_calendar

    errors.add(:event_calendar, "must be a master calendar") unless event_calendar.master?
  end

  def normalize_tag_filter
    self.tag_filter = Array(tag_filter)
                        .reject(&:blank?)
                        .map { |value| value.to_i }
                        .uniq
  end

  def validate_tag_filter
    return unless event_calendar

    valid_ids = event_calendar.event_calendar_tags.pluck(:id)
    invalid_ids = tag_filter - valid_ids
    errors.add(:tag_filter, "contains unknown tags") if invalid_ids.any?
  end
end
