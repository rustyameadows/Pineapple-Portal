class GlobalVendor < ApplicationRecord
  has_many :event_vendors, dependent: :restrict_with_error
  has_many :contacts,
           -> { ordered },
           class_name: "GlobalVendorContact",
           inverse_of: :global_vendor,
           dependent: :destroy

  accepts_nested_attributes_for :contacts, allow_destroy: true, reject_if: :contact_attributes_blank?

  before_validation :normalize_name_fields
  validates :name, presence: true
  validates :normalized_name, presence: true, uniqueness: { case_sensitive: true }

  scope :ordered, -> { order(Arel.sql("LOWER(name) ASC"), :id) }

  def self.normalize_name(value)
    value.to_s.strip.gsub(/\s+/, " ").downcase
  end

  private

  def normalize_name_fields
    self.name = name.to_s.strip.gsub(/\s+/, " ")
    self.normalized_name = self.class.normalize_name(name)
  end

  def contact_attributes_blank?(attributes)
    GlobalVendorContact::ATTRIBUTES.all? { |attribute| attributes[attribute].blank? }
  end
end
