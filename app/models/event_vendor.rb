class EventVendor < ApplicationRecord
  CONTACT_ATTRIBUTE_KEYS = %w[name title email phone notes].freeze

  belongs_to :event
  belongs_to :global_vendor, optional: true

  attr_writer :contacts_attributes

  before_validation :strip_name
  before_validation :sync_name_from_global_vendor
  before_validation :normalize_vendor_type
  before_validation :normalize_social_handle
  before_validation :normalize_team_meals
  before_validation :assign_position, on: :create
  before_validation :apply_contacts_attributes
  before_validation :ensure_contacts_default
  validates :name, presence: true, uniqueness: { scope: :event_id, case_sensitive: false }
  validates :position, numericality: { greater_than_or_equal_to: 0, allow_nil: false }
  validates :client_visible, inclusion: { in: [true, false] }
  validates :vendor_type, length: { maximum: 150 }, allow_blank: true
  validates :social_handle, length: { maximum: 150 }, allow_blank: true
  validate :contacts_jsonb_must_be_array_of_hashes

  scope :ordered, -> { order(:position, :id) }
  scope :client_visible, -> { where(client_visible: true) }

  def contacts
    return global_vendor.contacts if global_vendor

    contacts_jsonb || []
  end

  def contacts_attributes
    @contacts_attributes || contacts
  end

  private

  def sync_name_from_global_vendor
    return unless global_vendor

    self.name = global_vendor.name
    self.vendor_type = global_vendor.default_vendor_type if vendor_type.blank? && global_vendor.default_vendor_type.present?
    self.social_handle = global_vendor.default_social_handle if social_handle.blank? && global_vendor.default_social_handle.present?
  end

  def strip_name
    self.name = name.to_s.strip
  end

  def normalize_vendor_type
    self.vendor_type = vendor_type.to_s.strip.presence
  end

  def normalize_social_handle
    handle = social_handle.to_s.strip
    self.social_handle = handle.presence
  end

  def normalize_team_meals
    self.team_meals = team_meals.to_s.strip.presence
  end

  def assign_position
    return if event.nil?
    return unless new_record? || position.nil?

    max_position = EventVendor.where(event_id: event_id).where.not(id: id).maximum(:position)
    self.position = max_position.to_i + 1
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
        if value.is_a?(String)
          stripped = value.strip
          stripped.presence
        else
          value
        end
      end

      next if CONTACT_ATTRIBUTE_KEYS.all? { |key| contact_hash[key].blank? }

      CONTACT_ATTRIBUTE_KEYS.index_with { |key| contact_hash[key] }
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
