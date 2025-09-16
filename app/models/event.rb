class Event < ApplicationRecord
  has_many :questionnaires, dependent: :destroy
  has_many :questions, through: :questionnaires
  has_many :documents, dependent: :destroy
  has_many :attachments, as: :entity, dependent: :destroy

  validates :name, presence: true
end
