class DocumentBuild < ApplicationRecord
  belongs_to :document
  belongs_to :built_by_user, class_name: "User", optional: true

  BUILD_KINDS = {
    snapshot: "snapshot",
    working: "working"
  }.freeze
  STATUSES = {
    pending: "pending",
    running: "running",
    succeeded: "succeeded",
    failed: "failed",
    cancelled: "cancelled"
  }.freeze
  ACTIVE_STATUSES = [STATUSES[:pending], STATUSES[:running]].freeze
  PROGRESS_STAGES = {
    queued: "queued",
    preparing_pdf: "preparing_pdf",
    rendering_entries: "rendering_entries",
    assembling_pdf: "assembling_pdf",
    adding_page_numbers: "adding_page_numbers",
    uploading_pdf: "uploading_pdf",
    finalizing_pdf: "finalizing_pdf"
  }.freeze

  enum :build_kind, BUILD_KINDS, default: :snapshot, validate: true
  enum :status, STATUSES, validate: true

  validates :build_id, presence: true, uniqueness: true
  validates :page_numbers, inclusion: { in: [true, false] }

  scope :recent_first, -> { order(created_at: :desc, id: :desc) }
  scope :in_progress, -> { where(status: ACTIVE_STATUSES) }
  scope :successful, -> { where(status: STATUSES[:succeeded]) }
  scope :working_kind, -> { where(build_kind: BUILD_KINDS[:working]) }
  scope :snapshot_kind, -> { where(build_kind: BUILD_KINDS[:snapshot]) }
  scope :working, -> { working_kind }
  scope :snapshots, -> { snapshot_kind }

  before_validation :assign_build_id, on: :create
  before_validation :assign_defaults, on: :create

  def mark_running!
    return if cancelled?

    update!(
      status: STATUSES[:running],
      started_at: started_at || Time.current,
      error_message: nil
    )
  end

  def mark_succeeded!(result)
    return if cancelled?

    attrs = {
      status: STATUSES[:succeeded],
      finished_at: Time.current,
      compiled_page_count: result.page_count,
      file_size: result.file_size,
      checksum_sha256: result.checksum_sha256,
      error_message: nil
    }
    attrs[:storage_uri] = result.storage_uri if result.respond_to?(:storage_uri)
    attrs[:manifest_hash] = result.manifest_hash if result.respond_to?(:manifest_hash)
    attrs[:page_numbers] = result.page_numbers if result.respond_to?(:page_numbers) && !result.page_numbers.nil?

    update!(attrs)
  end

  def mark_failed!(error)
    return if cancelled?

    update!(
      status: STATUSES[:failed],
      finished_at: Time.current,
      error_message: error_message_from(error)
    )
  end

  def mark_cancelled!
    return if cancelled?

    update!(
      status: STATUSES[:cancelled],
      finished_at: Time.current,
      error_message: nil
    )
  end

  def cancelable?
    pending? || running?
  end

  def active?
    pending? || running?
  end

  def artifact_available?
    storage_uri.present? && succeeded?
  end

  def report_progress!(stage:, message: nil, current: nil, total: nil)
    normalized_stage = normalize_progress_stage(stage)

    update!(
      progress_stage: normalized_stage,
      progress_message: message.presence || default_progress_message(normalized_stage, current:, total:),
      progress_current: current,
      progress_total: total,
      last_progress_at: Time.current
    )
  end

  def display_progress_message
    progress_message.presence || default_progress_message(progress_stage, current: progress_current, total: progress_total)
  end

  def progress_payload
    {
      build_id: build_id,
      build_kind: build_kind,
      status: status,
      progress_stage: progress_stage,
      progress_message: display_progress_message,
      progress_current: progress_current,
      progress_total: progress_total,
      last_progress_at: last_progress_at&.utc&.iso8601
    }
  end

  def rendered_at
    finished_at || updated_at
  end

  def viewer_token
    [manifest_hash, checksum_sha256].compact.join("-").presence || build_id
  end

  private

  def assign_build_id
    self.build_id ||= SecureRandom.uuid
  end

  def assign_defaults
    self.build_kind ||= BUILD_KINDS[:snapshot]
    self.page_numbers = true if page_numbers.nil?
  end

  def error_message_from(error)
    message = error.respond_to?(:message) ? error.message.to_s : error.to_s
    message.presence || "Unknown error"
  end

  def normalize_progress_stage(stage)
    value = stage.to_s
    return if value.blank?

    PROGRESS_STAGES.fetch(value.to_sym) { value }
  end

  def default_progress_message(stage, current:, total:)
    case stage
    when PROGRESS_STAGES[:queued]
      working? ? "Live PDF queued" : "Snapshot queued"
    when PROGRESS_STAGES[:preparing_pdf]
      working? ? "Preparing live PDF" : "Preparing snapshot"
    when PROGRESS_STAGES[:rendering_entries]
      if current.present? && total.present?
        "Rendering pages #{current}/#{total}"
      else
        "Rendering pages"
      end
    when PROGRESS_STAGES[:assembling_pdf]
      "Assembling PDF"
    when PROGRESS_STAGES[:adding_page_numbers]
      "Adding page numbers"
    when PROGRESS_STAGES[:uploading_pdf]
      working? ? "Uploading live PDF" : "Uploading snapshot"
    when PROGRESS_STAGES[:finalizing_pdf]
      working? ? "Finalizing live PDF" : "Finalizing snapshot"
    else
      default_status_message
    end
  end

  def default_status_message
    case status
    when STATUSES[:pending]
      working? ? "Live PDF queued" : "Snapshot queued"
    when STATUSES[:running]
      working? ? "Preparing live PDF" : "Preparing snapshot"
    when STATUSES[:succeeded]
      working? ? "Live PDF ready" : "Snapshot ready"
    when STATUSES[:failed]
      working? ? "Live PDF failed" : "Snapshot failed"
    when STATUSES[:cancelled]
      working? ? "Live PDF cancelled" : "Snapshot cancelled"
    end
  end
end
