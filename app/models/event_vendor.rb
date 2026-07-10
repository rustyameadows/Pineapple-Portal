class EventVendor < ApplicationRecord
  belongs_to :event
  belongs_to :global_vendor

  has_many :event_vendor_contacts,
           -> { ordered },
           inverse_of: :event_vendor,
           dependent: :destroy
  has_many :contacts,
           through: :event_vendor_contacts,
           source: :global_vendor_contact

  before_validation :strip_name
  before_validation :sync_name_from_global_vendor
  before_validation :normalize_vendor_type
  before_validation :normalize_social_handle
  before_validation :normalize_team_meals
  before_validation :assign_position, on: :create
  before_destroy :prevent_planning_company_removal
  validates :name, presence: true, uniqueness: { scope: :event_id, case_sensitive: false }
  validates :global_vendor_id, uniqueness: { scope: :event_id }
  validates :position, numericality: { greater_than_or_equal_to: 0, allow_nil: false }
  validates :client_visible, inclusion: { in: [ true, false ] }
  validates :vendor_type, length: { maximum: 150 }, allow_blank: true
  validates :social_handle, length: { maximum: 150 }, allow_blank: true
  validate :selected_contacts_belong_to_global_vendor

  scope :ordered, -> { order(:position, :id) }
  scope :client_visible, -> { where(client_visible: true) }

  def selected_contacts
    event_vendor_contacts
      .includes(:global_vendor_contact)
      .ordered
      .map(&:global_vendor_contact)
  end

  def selected_contact_ids
    event_vendor_contacts.ordered.pluck(:global_vendor_contact_id)
  end

  def replace_contact_ids!(ids)
    requested_ids = Array(ids).reject(&:blank?).map { |id| Integer(id.to_s, 10) }.uniq
    available_contacts = global_vendor.contacts.where(id: requested_ids).index_by(&:id)
    missing_ids = requested_ids - available_contacts.keys
    raise ActiveRecord::RecordNotFound, "Contacts do not belong to this vendor: #{missing_ids.join(', ')}" if missing_ids.any?
    return selected_contacts if selected_contact_ids == requested_ids

    transaction do
      event_vendor_contacts.delete_all
      requested_ids.each_with_index do |contact_id, position|
        event_vendor_contacts.create!(global_vendor_contact_id: contact_id, position: position)
      end
    end

    event_vendor_contacts.reload
    selected_contacts
  end

  private

  def prevent_planning_company_removal
    return unless global_vendor&.planning_company?
    return if destroyed_by_association&.name == :event_vendors

    errors.add(:base, "The planning company must remain associated with every event")
    throw :abort
  end

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

  def selected_contacts_belong_to_global_vendor
    return if global_vendor_id.blank?
    return unless contacts.where.not(global_vendor_id: global_vendor_id).exists?

    errors.add(:selected_contacts, "must belong to the selected global vendor")
  end
end
