class GlobalVendor < ApplicationRecord
  CONTACT_ATTRIBUTE_KEYS = %w[name title email phone notes].freeze

  has_many :event_vendors, dependent: :nullify

  attr_writer :contacts_attributes

  before_validation :normalize_name_fields
  before_validation :apply_contacts_attributes
  before_validation :ensure_contacts_default
  validates :name, presence: true
  validates :normalized_name, presence: true, uniqueness: { case_sensitive: true }
  validate :contacts_jsonb_must_be_array_of_hashes

  scope :ordered, -> { order(Arel.sql("LOWER(name) ASC"), :id) }

  def self.normalize_name(value)
    value.to_s.strip.gsub(/\s+/, " ").downcase
  end

  def contacts
    contacts_jsonb || []
  end

  def contacts_attributes
    @contacts_attributes || contacts
  end

  private

  def normalize_name_fields
    self.name = name.to_s.strip.gsub(/\s+/, " ")
    self.normalized_name = self.class.normalize_name(name)
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
