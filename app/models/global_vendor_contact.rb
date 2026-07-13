class GlobalVendorContact < ApplicationRecord
  ATTRIBUTES = %w[name title email phone notes].freeze

  belongs_to :global_vendor, inverse_of: :contacts

  has_many :event_vendor_contacts,
           inverse_of: :global_vendor_contact,
           dependent: :destroy
  has_many :event_vendors, through: :event_vendor_contacts

  before_validation :normalize_attributes
  before_validation :assign_position, on: :create

  validates :position, numericality: { greater_than_or_equal_to: 0, allow_nil: false }
  validate :at_least_one_attribute_present
  validate :selected_events_belong_to_global_vendor

  scope :ordered, -> { order(:position, :id) }

  def to_h
    ATTRIBUTES.index_with { |attribute| self[attribute] }
  end

  private

  def normalize_attributes
    ATTRIBUTES.each do |attribute|
      self[attribute] = self[attribute].to_s.strip.presence
    end
  end

  def assign_position
    return if global_vendor.nil?
    return unless new_record? || position.nil?

    max_position = GlobalVendorContact
                   .where(global_vendor_id: global_vendor_id)
                   .where.not(id: id)
                   .maximum(:position)
    self.position = max_position.to_i + 1
  end

  def at_least_one_attribute_present
    return if ATTRIBUTES.any? { |attribute| self[attribute].present? }

    errors.add(:base, "Contact must include at least one detail")
  end

  def selected_events_belong_to_global_vendor
    return if global_vendor_id.blank? || event_vendor_contacts.empty?
    return unless event_vendors.where.not(global_vendor_id: global_vendor_id).exists?

    errors.add(:global_vendor, "must match every event vendor that selects this contact")
  end
end
