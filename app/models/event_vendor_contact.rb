class EventVendorContact < ApplicationRecord
  belongs_to :event_vendor, inverse_of: :event_vendor_contacts
  belongs_to :global_vendor_contact, inverse_of: :event_vendor_contacts

  before_validation :assign_position, on: :create

  validates :global_vendor_contact_id, uniqueness: { scope: :event_vendor_id }
  validates :position, numericality: { greater_than_or_equal_to: 0, allow_nil: false }
  validate :contact_belongs_to_event_vendors_global_vendor

  scope :ordered, -> { order(:position, :id) }

  private

  def assign_position
    return if event_vendor.nil?
    return unless new_record? || position.nil?

    max_position = EventVendorContact
                   .where(event_vendor_id: event_vendor_id)
                   .where.not(id: id)
                   .maximum(:position)
    self.position = max_position.to_i + 1
  end

  def contact_belongs_to_event_vendors_global_vendor
    return if event_vendor.nil? || global_vendor_contact.nil?
    return if event_vendor.global_vendor_id == global_vendor_contact.global_vendor_id

    errors.add(:global_vendor_contact, "must belong to the event vendor's global vendor")
  end
end
