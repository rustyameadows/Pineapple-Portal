class DocumentBuild < ApplicationRecord
  belongs_to :document
  belongs_to :built_by_user, class_name: "User", optional: true

  STATUSES = {
    pending: "pending",
    running: "running",
    succeeded: "succeeded",
    failed: "failed",
    cancelled: "cancelled"
  }.freeze

  enum :status, STATUSES, validate: true

  validates :build_id, presence: true, uniqueness: true

  scope :recent_first, -> { order(created_at: :desc) }
  scope :in_progress, -> { where(status: [STATUSES[:pending], STATUSES[:running]]) }

  before_validation :assign_build_id, on: :create

  def mark_running!
    return if cancelled?

    update!(
      status: STATUSES[:running],
      started_at: Time.current,
      error_message: nil
    )
  end

  def mark_succeeded!(result)
    return if cancelled?

    update!(
      status: STATUSES[:succeeded],
      finished_at: Time.current,
      compiled_page_count: result.page_count,
      file_size: result.file_size,
      checksum_sha256: result.checksum_sha256,
      error_message: nil
    )
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

  private

  def assign_build_id
    self.build_id ||= SecureRandom.uuid
  end

  def error_message_from(error)
    message = error.respond_to?(:message) ? error.message.to_s : error.to_s
    message.presence || "Unknown error"
  end
end
