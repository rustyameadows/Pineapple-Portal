class EventKeyPersonGroup < ApplicationRecord
  AUTO_TAG_PREFIX = "Wedding Party Side".freeze
  AUTO_TAG_COLOR = RunOfShowDefaults::TAGS.find { |tag| tag[:name] == "Wedding Party Reference" }&.fetch(:color_token, nil)

  belongs_to :event
  belongs_to :event_calendar_tag

  has_many :event_guests, -> { order(:position, :id) }, dependent: :restrict_with_error

  scope :ordered, -> { order(:position, :id) }

  validates :name, presence: true, uniqueness: { scope: :event_id, case_sensitive: false }
  validates :position, numericality: { greater_than_or_equal_to: 0 }
  validate :event_calendar_tag_must_belong_to_event_calendar

  before_validation :normalize_name
  before_validation :assign_position, on: :create
  after_save :sync_event_guest_group_names, if: :saved_change_to_name?

  class << self
    def backfill_for_event!(event)
      groups_by_name = {}

      event.event_guests.key_people.ordered.each do |guest|
        normalized_name = guest.group_name.to_s.strip
        next if normalized_name.blank?

        key = normalized_name.downcase
        groups_by_name[key] ||= event.ensure_key_person_group!(normalized_name)
        group = groups_by_name[key]

        updates = {}
        updates[:event_key_person_group_id] = group.id if guest.event_key_person_group_id != group.id
        updates[:group_name] = group.name if guest.group_name != group.name
        next if updates.empty?

        guest.update_columns(updates.merge(updated_at: Time.current)) # rubocop:disable Rails/SkipsModelValidations
      end
    end

    def next_auto_tag_name(calendar)
      existing_names = calendar.event_calendar_tags.pluck(:name).map(&:to_s)
      index = 0

      loop do
        candidate = "#{AUTO_TAG_PREFIX} #{index_to_slot_label(index)}"
        return candidate unless existing_names.any? { |name| name.casecmp?(candidate) }

        index += 1
      end
    end

    def index_to_slot_label(index)
      value = index.to_i
      label = +""

      loop do
        label.prepend((65 + (value % 26)).chr)
        value = (value / 26) - 1
        break if value.negative?
      end

      label
    end
  end

  private

  def normalize_name
    self.name = name.to_s.strip.presence
  end

  def assign_position
    return unless event_id.present?

    self.position = event.event_key_person_groups.where.not(id: id).maximum(:position).to_i + 1 if position.nil?
  end

  def event_calendar_tag_must_belong_to_event_calendar
    return if event.blank? || event_calendar_tag.blank?

    unless event_calendar_tag.event_calendar&.event_id == event_id
      errors.add(:event_calendar_tag, "must belong to this event")
    end
  end

  def sync_event_guest_group_names
    event_guests.update_all(group_name: name, updated_at: Time.current) # rubocop:disable Rails/SkipsModelValidations
  end
end
