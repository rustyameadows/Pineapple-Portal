class Document < ApplicationRecord
  DOC_KINDS = {
    uploaded: "uploaded",
    generated: "generated"
  }.freeze

  PACKET_SCHEMA_VERSIONS = {
    legacy: 1,
    source_backed: 2
  }.freeze

  PACKET_CONTAINER_KINDS = {
    packet: "packet",
    group: "group"
  }.freeze

  WORKING_STATUSES = {
    missing: "missing",
    fresh: "fresh",
    refreshing: "refreshing",
    failed: "failed"
  }.freeze
  WORKING_REFRESH_TIMEOUT = 10.minutes

  UUID_REGEX = /\A[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\z/i.freeze

  belongs_to :event
  belongs_to :built_by_user, class_name: "User", optional: true

  has_many :attachments, dependent: :destroy
  has_many :builds,
           class_name: "DocumentBuild",
           dependent: :destroy
  has_many :snapshot_builds,
           -> { where(build_kind: DocumentBuild::BUILD_KINDS[:snapshot]) },
           class_name: "DocumentBuild"
  has_many :working_builds,
           -> { where(build_kind: DocumentBuild::BUILD_KINDS[:working]) },
           class_name: "DocumentBuild"
  has_many :segments,
           -> { order(:position) },
           class_name: "DocumentSegment",
           foreign_key: :document_logical_id,
           primary_key: :logical_id,
           dependent: :destroy
  has_many :packet_placements,
           -> { order(:position) },
           class_name: "GeneratedPacketPlacement",
           foreign_key: :document_logical_id,
           primary_key: :logical_id,
           dependent: :destroy
  has_many :generated_packet_sources,
           through: :packet_placements,
           source: :source
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
  validates :working_status, inclusion: { in: WORKING_STATUSES.values }
  validates :packet_container_kind, inclusion: { in: PACKET_CONTAINER_KINDS.values }, if: :generated?

  scope :generated, -> { where(doc_kind: DOC_KINDS[:generated]) }
  scope :templates, -> { where(is_template: true) }
  scope :packet_containers, -> { where(packet_container_kind: PACKET_CONTAINER_KINDS[:packet]) }
  scope :group_containers, -> { where(packet_container_kind: PACKET_CONTAINER_KINDS[:group]) }

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
    packet_definitions = event.documents.generated.packet_containers.where(storage_uri: nil)
    return [] unless packet_definitions.exists?

    packet_definitions.flat_map do |document|
      if document.packet_source_backed?
        Documents::Generated::ContainerEntries.new(definition_document: document).call.filter_map do |entry|
          next unless entry.source.pdf_asset?

          normalize_uuid(entry.source.pdf_logical_id)
        end
      else
        document.segments.filter_map do |segment|
          next unless segment.pdf_asset?

          normalize_uuid(segment.pdf_logical_id)
        end
      end
    end.uniq
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

  PACKET_CONTAINER_KINDS.each_key do |key|
    define_method "#{key}_container?" do
      packet_container_kind == PACKET_CONTAINER_KINDS[key]
    end
  end

  WORKING_STATUSES.each_key do |key|
    define_method "working_#{key}?" do
      working_status_key == WORKING_STATUSES[key]
    end
  end

  def working_available?
    working_storage_uri.present?
  end

  def working_storage_uri
    current_working_artifact_build&.storage_uri.presence || self[:working_storage_uri]
  end

  def working_manifest_hash
    current_working_artifact_build&.manifest_hash.presence || self[:working_manifest_hash]
  end

  def working_checksum_sha256
    current_working_artifact_build&.checksum_sha256.presence || self[:working_checksum_sha256]
  end

  def working_page_count
    current_working_artifact_build&.compiled_page_count.presence || self[:working_page_count]
  end

  def working_file_size
    current_working_artifact_build&.file_size.presence || self[:working_file_size]
  end

  def working_rendered_at
    current_working_artifact_build&.rendered_at || self[:working_rendered_at]
  end

  def working_refresh_error
    progress_build = current_working_progress_build
    if progress_build&.failed?
      progress_build.error_message.presence || self[:working_refresh_error]
    else
      self[:working_refresh_error]
    end
  end

  def working_status_key
    return WORKING_STATUSES[:refreshing] if active_working_build.present?

    latest_build = latest_working_build
    return WORKING_STATUSES[:failed] if latest_build&.failed?
    return WORKING_STATUSES[:fresh] if current_working_artifact_build.present?

    status = self[:working_status].to_s
    return WORKING_STATUSES[:fresh] if working_available? && status == WORKING_STATUSES[:missing]
    return WORKING_STATUSES[:missing] if status.blank?

    WORKING_STATUSES.value?(status) ? status : WORKING_STATUSES[:missing]
  end

  def working_refreshing?
    working_status_key == WORKING_STATUSES[:refreshing]
  end

  def working_failed?
    working_status_key == WORKING_STATUSES[:failed]
  end

  def working_fresh?
    working_available? && working_status_key == WORKING_STATUSES[:fresh]
  end

  def working_viewer_token
    current_working_artifact_build&.viewer_token.presence ||
      [self[:working_manifest_hash], self[:working_rendered_at]&.utc&.to_i].compact.join("-").presence ||
      "missing"
  end

  def working_refresh_locked?
    active_build = active_working_build
    return true if active_build.present? && !active_build.stale?(timeout: WORKING_REFRESH_TIMEOUT)

    return false unless working_refreshing?

    reference_time = working_refresh_started_at || working_refresh_requested_at
    reference_time.present? && reference_time >= WORKING_REFRESH_TIMEOUT.ago
  end

  def request_working_refresh!
    with_lock do
      reload
      return false if working_refresh_locked?

      update_columns(
        working_status: WORKING_STATUSES[:refreshing],
        working_refresh_requested_at: Time.current,
        working_refresh_started_at: nil,
        working_refresh_error: nil
      )
    end

    true
  end

  def mark_working_refresh_started!
    update_columns(
      working_status: WORKING_STATUSES[:refreshing],
      working_refresh_started_at: Time.current,
      working_refresh_error: nil
    )
  end

  def mark_working_fresh!(attrs = {})
    update_columns(
      {
        working_status: WORKING_STATUSES[:fresh],
        working_refresh_requested_at: nil,
        working_refresh_started_at: nil,
        working_refresh_error: nil
      }.merge(attrs)
    )
  end

  def mark_working_failed!(message)
    update_columns(
      working_status: WORKING_STATUSES[:failed],
      working_refresh_requested_at: nil,
      working_refresh_started_at: nil,
      working_refresh_error: message.to_s.presence
    )
  end

  def clear_working_copy!
    builds.working_kind.delete_all if persisted?

    update_columns(
      working_storage_uri: nil,
      working_manifest_hash: nil,
      working_checksum_sha256: nil,
      working_page_count: nil,
      working_file_size: nil,
      working_rendered_at: nil,
      working_status: WORKING_STATUSES[:missing],
      working_refresh_requested_at: nil,
      working_refresh_started_at: nil,
      working_refresh_error: nil
    )
  end

  def active_working_build
    working_builds.in_progress.recent_first.detect do |build|
      !build.stale?(timeout: WORKING_REFRESH_TIMEOUT)
    end
  end

  def stale_working_build
    build = working_builds.in_progress.recent_first.first
    return unless build&.stale?(timeout: WORKING_REFRESH_TIMEOUT)

    build
  end

  def recover_stale_working_build!
    with_lock do
      reload

      build = working_builds.in_progress.recent_first.first
      next unless build&.stale?(timeout: WORKING_REFRESH_TIMEOUT)

      build.mark_failed!(build.stale_error_message(timeout: WORKING_REFRESH_TIMEOUT))
      build
    end
  end

  def latest_working_build
    working_builds.recent_first.first
  end

  def latest_successful_working_build
    working_builds.successful.recent_first.first
  end

  def current_working_artifact_build
    latest_successful_working_build
  end

  def current_working_progress_build
    active_build = active_working_build
    return active_build if active_build.present?

    latest_build = latest_working_build
    return latest_build if latest_build&.failed?
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

  def packet_source_backed?
    packet_schema_version.to_i >= PACKET_SCHEMA_VERSIONS[:source_backed]
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
      self.packet_schema_version ||= PACKET_SCHEMA_VERSIONS[:legacy]
      self.packet_container_kind ||= PACKET_CONTAINER_KINDS[:packet]
      self.working_status ||= WORKING_STATUSES[:missing]
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
