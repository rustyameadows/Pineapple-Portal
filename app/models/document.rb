class Document < ApplicationRecord
  belongs_to :event
  has_many :attachments, dependent: :destroy

  before_validation :assign_defaults, on: :create
  before_create :demote_existing_latest
  before_update :prevent_file_metadata_change

  validates :title, :storage_uri, :checksum, :content_type, presence: true
  validates :size_bytes, numericality: { greater_than: 0 }
  validates :version, numericality: { greater_than: 0 }
  validates :logical_id, presence: true
  validates :is_latest, inclusion: { in: [true, false] }

  scope :latest, -> { where(is_latest: true) }
  scope :client_visible, -> { where(client_visible: true) }

  def self.next_version_for(logical_id)
    where(logical_id: logical_id).maximum(:version).to_i + 1
  end

  def physical_key
    storage_uri
  end

  private

  def assign_defaults
    self.logical_id ||= SecureRandom.uuid
    self.version ||= next_version_number
    self.is_latest = true if is_latest.nil?
  end

  def next_version_number
    last_version = self.class.where(logical_id: logical_id).maximum(:version)
    last_version.to_i + 1
  end

  def prevent_file_metadata_change
    return unless will_save_change_to_storage_uri? || will_save_change_to_checksum? ||
                  will_save_change_to_size_bytes? || will_save_change_to_content_type?

    errors.add(:base, "File metadata cannot be changed once uploaded")
    throw :abort
  end

  def demote_existing_latest
    return if logical_id.blank?

    self.class.where(logical_id: logical_id, is_latest: true).update_all(is_latest: false)
  end
end
