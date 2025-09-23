class Event < ApplicationRecord
  has_many :questionnaires, dependent: :destroy
  has_many :questions, through: :questionnaires
  has_many :documents, dependent: :destroy
  has_many :attachments, as: :entity, dependent: :destroy
  has_many :event_links, -> { order(:position, :id) }, dependent: :destroy

  scope :active, -> { where(archived_at: nil) }
  scope :archived, -> { where.not(archived_at: nil) }

  validates :name, presence: true

  def archived?
    archived_at.present?
  end
end
