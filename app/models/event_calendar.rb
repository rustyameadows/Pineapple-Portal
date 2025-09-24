class EventCalendar < ApplicationRecord
  DEFAULT_TIMEZONE = "America/New_York".freeze
  KINDS = {
    master: "master",
    derived: "derived"
  }.freeze

  belongs_to :event
  belongs_to :template_source, class_name: "CalendarTemplate", optional: true

  has_many :calendar_items, dependent: :destroy
  has_many :event_calendar_tags, dependent: :destroy
  has_many :event_calendar_views, dependent: :destroy

  attribute :kind, :string
  enum :kind, KINDS, validate: true

  validates :name, presence: true
  validates :slug, presence: true, uniqueness: { scope: :event_id }
  validates :timezone, presence: true
  validates :kind, presence: true
  validate :single_master_per_event, if: :master?
  validate :template_source_kind_compatibility

  before_validation :set_default_timezone
  before_validation :generate_slug, if: -> { slug.blank? && name.present? }

  scope :master, -> { where(kind: KINDS[:master]) }
  scope :derived, -> { where(kind: KINDS[:derived]) }

  def run_of_show?
    master?
  end

  private

  def generate_slug
    base = name.to_s.parameterize
    return self.slug = base if base.blank?

    candidate = base
    suffix = 2
    existing_scope = EventCalendar.where(event_id: event_id)
    existing_scope = existing_scope.where.not(id: id) if id

    while existing_scope.exists?(slug: candidate)
      candidate = "#{base}-#{suffix}"
      suffix += 1
    end

    self.slug = candidate
  end

  def set_default_timezone
    self.timezone = timezone.presence || DEFAULT_TIMEZONE
  end

  def single_master_per_event
    return unless event_id.present?
    scope = EventCalendar.master.where(event_id: event_id)
    scope = scope.where.not(id: id) if id
    errors.add(:kind, "already has a master calendar") if scope.exists?
  end

  def template_source_kind_compatibility
    return if template_source_id.blank?
    return if template_source.present?

    errors.add(:template_source_id, "must reference an existing calendar template")
  end
end
