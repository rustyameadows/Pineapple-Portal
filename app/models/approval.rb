class Approval < ApplicationRecord
  STATUSES = {
    pending: "pending",
    acknowledged: "acknowledged"
  }.freeze

  belongs_to :event
  has_many :attachments, as: :entity, dependent: :destroy

  enum :status, STATUSES, default: :pending, validate: true

  validates :title, presence: true

  scope :ordered, -> { order(:created_at) }
  scope :client_visible, -> { where(client_visible: true) }

  def acknowledge!(timestamp: Time.current, name: nil, note: nil)
    assign_attributes(status: :acknowledged, acknowledged_at: timestamp)
    self.client_name = name if name.present?
    self.client_note = note if note.present?
    save!
  end
end
