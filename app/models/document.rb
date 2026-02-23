class Document < ApplicationRecord
  DOC_KINDS = {
    uploaded: "uploaded",
    generated: "generated"
  }.freeze

  UUID_REGEX = /\A[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\z/i.freeze

  belongs_to :event
  belongs_to :built_by_user, class_name: "User", optional: true

  has_many :attachments, dependent: :destroy
  has_many :builds,
           class_name: "DocumentBuild",
           dependent: :destroy
  has_many :segments,
           -> { order(:position) },
           class_name: "DocumentSegment",
           foreign_key: :document_logical_id,
           primary_key: :logical_id,
           dependent: :destroy
  has_many :document_dependencies,
           class_name: "DocumentDependency",
           foreign_key: :document_logical_id,
           primary_key: :logical_id,
           dependent: :destroy

  before_validation :assign_defaults, on: :create
  before_create :demote_existing_latest
  before_update :prevent_file_metadata_change

  SOURCE_KEYS = %w[packet staff_upload client_upload].freeze
  STAFF_SOURCE_KEYS = (SOURCE_KEYS - ["client_upload"]).freeze

  SOURCE_LABELS = {
    "packet" => "Packets",
    "staff_upload" => "Uploads",
    "client_upload" => "Client Uploads"
  }.freeze

  validates :title, presence: true
  validates :storage_uri, :checksum, :content_type, presence: true, if: :requires_file_metadata?
  validates :size_bytes, numericality: { greater_than: 0 }, if: :requires_file_metadata?
  validates :version, numericality: { greater_than: 0 }
  validates :logical_id, presence: true
  validates :is_latest, inclusion: { in: [true, false] }
  validates :source, inclusion: { in: SOURCE_KEYS }
  validates :doc_kind, inclusion: { in: DOC_KINDS.values }

  scope :generated, -> { where(doc_kind: DOC_KINDS[:generated]) }
  scope :templates, -> { where(is_template: true) }

  scope :latest, -> { where(is_latest: true) }
  scope :with_stored_file, -> { where.not(storage_uri: nil) }
  scope :excluding_client_uploads, -> { where.not(source: "client_upload") }
  scope :client_visible, -> { where(client_visible: true) }
  scope :financial_portal_visible, -> { where(financial_portal_visible: true) }
  scope :packets_portal_visible, -> { where(packets_portal_visible: true) }
  scope :packets_portal_listing, -> { latest.with_stored_file.excluding_client_uploads.packets_portal_visible }

  def self.source_label(key)
    SOURCE_LABELS[key.to_s] || key.to_s.humanize
  end

  def self.sources
    SOURCE_KEYS.index_with(&:to_s)
  end

  def self.staff_sources
    STAFF_SOURCE_KEYS.index_with(&:to_s)
  end

  def self.doc_kinds
    DOC_KINDS.transform_values(&:dup)
  end

  def self.packet_component_logical_ids_for_event(event)
    generated_logical_ids = event.documents.generated.select(:logical_id)
    return [] unless generated_logical_ids.exists?

    DocumentSegment
      .where(document_logical_id: generated_logical_ids, kind: DocumentSegment::KINDS[:pdf_asset])
      .pluck(Arel.sql("source_ref ->> 'logical_id'"))
      .filter_map { |value| normalize_uuid(value) }
      .uniq
  end

  def source_label
    self.class.source_label(source)
  end

  SOURCE_KEYS.each do |key|
    define_method "#{key}?" do
      source == key
    end
  end

  DOC_KINDS.each_key do |key|
    define_method "#{key}?" do
      doc_kind == DOC_KINDS[key]
    end
  end

  def self.next_version_for(logical_id)
    where(logical_id: logical_id).maximum(:version).to_i + 1
  end

  def physical_key
    storage_uri
  end

  def definition_placeholder?
    doc_kind == DOC_KINDS[:generated] && !requires_file_metadata?
  end

  def requires_file_metadata?
    doc_kind != DOC_KINDS[:generated] || storage_uri.present?
  end

  private

  def self.normalize_uuid(value)
    uuid = value.to_s.strip
    return if uuid.blank?
    return uuid if uuid.match?(UUID_REGEX)
  end
  private_class_method :normalize_uuid

  def assign_defaults
    self.logical_id ||= SecureRandom.uuid
    self.doc_kind ||= DOC_KINDS[:uploaded]
    self.version ||= next_version_number

    if doc_kind == DOC_KINDS[:generated]
      self.source ||= "packet"
      self.is_latest = false if definition_placeholder?
    else
      self.source ||= "staff_upload"
    end

    self.is_latest = true if is_latest.nil?
    self.is_template = false if is_template.nil?
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
