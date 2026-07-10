class GlobalVendor < ApplicationRecord
  SYSTEM_ROLES = {
    planning_company: "planning_company"
  }.freeze

  has_many :event_vendors, dependent: :restrict_with_error
  has_many :contacts,
           -> { ordered },
           class_name: "GlobalVendorContact",
           inverse_of: :global_vendor,
           dependent: :destroy

  accepts_nested_attributes_for :contacts, allow_destroy: true, reject_if: :contact_attributes_blank?

  before_validation :normalize_name_fields
  before_validation :normalize_system_role
  validates :name, presence: true
  validates :normalized_name, presence: true, uniqueness: { case_sensitive: true }
  validates :system_role,
            inclusion: { in: SYSTEM_ROLES.values },
            uniqueness: true,
            allow_nil: true

  scope :ordered, -> { order(Arel.sql("LOWER(name) ASC"), :id) }

  def self.normalize_name(value)
    value.to_s.strip.gsub(/\s+/, " ").downcase
  end

  def self.planning_company
    find_by(system_role: SYSTEM_ROLES.fetch(:planning_company))
  end

  def planning_company?
    system_role == SYSTEM_ROLES.fetch(:planning_company)
  end

  private

  def normalize_name_fields
    self.name = name.to_s.strip.gsub(/\s+/, " ")
    self.normalized_name = self.class.normalize_name(name)
  end

  def normalize_system_role
    self.system_role = system_role.to_s.strip.presence
  end

  def contact_attributes_blank?(attributes)
    GlobalVendorContact::ATTRIBUTES.all? { |attribute| attributes[attribute].blank? }
  end
end
