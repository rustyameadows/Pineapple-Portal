class Approval < ApplicationRecord
  STATUSES = {
    pending: "pending",
    approved: "approved",
    acknowledged: "acknowledged"
  }.freeze

  belongs_to :event
  has_many :attachments, as: :entity, dependent: :destroy

  enum :status, STATUSES, default: :pending, validate: true

  validates :title, presence: true

  scope :ordered, -> { order(:created_at) }
  scope :client_visible, -> { where(client_visible: true) }

  STATUS_LABELS = {
    pending: "Pending",
    approved: "Approved",
    acknowledged: "Returned with comments"
  }.freeze

  def approve!(timestamp: Time.current, name: nil)
    assign_attributes(status: :approved, acknowledged_at: timestamp)
    self.client_name = name if name.present?
    save!
  end

  def return_with_comments!(timestamp: Time.current, name: nil, note: nil)
    assign_attributes(status: :acknowledged, acknowledged_at: timestamp)
    self.client_name = name if name.present?
    self.client_note = note if note.present?
    save!
  end

  def status_label
    STATUS_LABELS.fetch(status.to_sym, status.to_s.humanize)
  end
end
