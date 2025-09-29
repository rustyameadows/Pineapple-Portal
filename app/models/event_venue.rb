class EventVenue < ApplicationRecord
  CONTACT_ATTRIBUTE_KEYS = %w[name title email phone notes].freeze

  belongs_to :event

  attr_writer :contacts_attributes

  before_validation :strip_name
  before_validation :assign_position, on: :create
  before_validation :apply_contacts_attributes
  before_validation :ensure_contacts_default

  validates :name, presence: true, uniqueness: { scope: :event_id, case_sensitive: false }
  validates :position, numericality: { greater_than_or_equal_to: 0, allow_nil: false }
  validates :client_visible, inclusion: { in: [true, false] }
  validate :contacts_jsonb_must_be_array_of_hashes

  scope :ordered, -> { order(:position, :id) }
  scope :client_visible, -> { where(client_visible: true) }

  def contacts
    contacts_jsonb || []
  end

  def contacts_attributes
    @contacts_attributes || contacts
  end

  private

  def strip_name
    self.name = name.to_s.strip
  end

  def assign_position
    return if position.present? || event.nil?

    self.position = event.event_venues.maximum(:position).to_i + 1
  end

  def apply_contacts_attributes
    return unless defined?(@contacts_attributes)

    raw_contacts = case @contacts_attributes
                   when Hash
                     @contacts_attributes.values
                   when Array
                     @contacts_attributes
                   else
                     []
                   end

    sanitized_contacts = raw_contacts.filter_map do |contact|
      contact_hash = contact.to_h.transform_keys(&:to_s).slice(*CONTACT_ATTRIBUTE_KEYS)
      contact_hash.transform_values! do |value|
        value.is_a?(String) ? value.strip : value
      end

      next if CONTACT_ATTRIBUTE_KEYS.all? { |key| contact_hash[key].blank? }

      contact_hash
    end

    self.contacts_jsonb = sanitized_contacts
  end

  def ensure_contacts_default
    self.contacts_jsonb ||= []
  end

  def contacts_jsonb_must_be_array_of_hashes
    return if contacts_jsonb.is_a?(Array) && contacts_jsonb.all? { |item| item.is_a?(Hash) }

    errors.add(:contacts_jsonb, "must be an array of contact hashes")
  end
end
