class CalendarItem < ApplicationRecord
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

  def absolute?
    relative_anchor_id.blank?
  end

  def relative?
    !absolute?
  end

  def effective_starts_at
    return starts_at if absolute?
    return unless relative_anchor&.effective_starts_at

    minutes = relative_offset_minutes.to_i
    anchor_time = relative_anchor.effective_starts_at
    offset = relative_before? ? -minutes : minutes
    anchor_time + offset.minutes
  end

  def locked?
    locked
  end

  def refresh_tag_summary!
    update_column(:tag_summary, event_calendar_tags.pluck(:name)) # rubocop:disable Rails/SkipsModelValidations
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
end
