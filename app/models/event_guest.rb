class EventGuest < ApplicationRecord
  KINDS = {
    key_person: "key_person",
    guest: "guest"
  }.freeze

  belongs_to :event
  belongs_to :event_key_person_group, optional: true

  enum :kind, KINDS, validate: true

  before_validation :normalize_fields
  before_validation :resolve_event_key_person_group_from_group_name
  before_validation :sync_group_name_from_group
  before_validation :assign_position, on: :create

  validates :kind, :first_name, :last_name, :relationship, :group_name, presence: true
  validates :event_key_person_group, presence: true, if: :key_person?
  validates :position, numericality: { greater_than_or_equal_to: 0, allow_nil: false }
  validates :vip, inclusion: { in: [true, false] }
  validate :event_key_person_group_must_belong_to_event

  scope :ordered, -> { order(:position, :id) }
  scope :key_people, -> { where(kind: KINDS[:key_person]) }

  def full_name
    [first_name, last_name].filter_map { |value| value.to_s.strip.presence }.join(" ")
  end

  private

  def normalize_fields
    self.kind = kind.to_s.strip.presence

    %i[first_name last_name relationship group_name].each do |attribute_name|
      self[attribute_name] = self[attribute_name].to_s.strip.presence
    end
  end

  def sync_group_name_from_group
    self.group_name = event_key_person_group&.name.presence || group_name
  end

  def resolve_event_key_person_group_from_group_name
    return unless key_person?
    return if event_key_person_group.present? || event.blank?

    normalized_group_name = group_name.to_s.strip.presence
    return if normalized_group_name.blank?

    self.event_key_person_group = event.event_key_person_groups.find_by("LOWER(name) = ?", normalized_group_name.downcase) ||
                                  event.ensure_key_person_group!(normalized_group_name)
  end

  def assign_position
    return if event.nil?
    return unless new_record? || position.nil?

    max_position = EventGuest.where(event_id: event_id).where.not(id: id).maximum(:position)
    self.position = max_position.to_i + 1
  end

  def event_key_person_group_must_belong_to_event
    return unless key_person?
    return if event_key_person_group.blank? || event.blank?

    if event_key_person_group.event_id != event_id
      errors.add(:event_key_person_group, "must belong to this event")
    end
  end
end
