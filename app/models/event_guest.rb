class EventGuest < ApplicationRecord
  KINDS = {
    key_person: "key_person",
    guest: "guest"
  }.freeze

  belongs_to :event

  enum :kind, KINDS, validate: true

  before_validation :normalize_fields
  before_validation :assign_position, on: :create

  validates :kind, :first_name, :last_name, :relationship, :group_name, presence: true
  validates :position, numericality: { greater_than_or_equal_to: 0, allow_nil: false }
  validates :vip, inclusion: { in: [true, false] }

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

  def assign_position
    return if event.nil?
    return unless new_record? || position.nil?

    max_position = EventGuest.where(event_id: event_id).where.not(id: id).maximum(:position)
    self.position = max_position.to_i + 1
  end
end
