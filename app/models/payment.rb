class Payment < ApplicationRecord
  STATUSES = {
    pending: "pending",
    paid: "paid"
  }.freeze

  belongs_to :event
  has_many :attachments, as: :entity, dependent: :destroy

  before_save :sync_paid_timestamps

  enum :status, STATUSES, default: :pending, validate: true

  validates :title, presence: true
  validates :amount, numericality: { greater_than_or_equal_to: 0 }

  scope :ordered, -> { order(Arel.sql("COALESCE(due_on, '9999-12-31')"), :created_at) }
  scope :client_visible, -> { where(client_visible: true) }
  scope :pending_first, -> { order(Arel.sql("CASE status WHEN 'pending' THEN 0 ELSE 1 END")) }

  def mark_paid!(timestamp: Time.current, by_client: false, note: nil)
    assign_attributes(status: :paid, paid_at: timestamp)
    self.paid_by_client_at = timestamp if by_client
    self.client_note = note if by_client && note.present?

    save!
  end

  private

  def sync_paid_timestamps
    if will_save_change_to_status?
      if paid?
        self.paid_at ||= Time.current
      else
        self.paid_at = nil
        self.paid_by_client_at = nil
      end
    end
  end
end
