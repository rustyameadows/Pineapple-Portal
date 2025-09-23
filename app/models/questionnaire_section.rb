class QuestionnaireSection < ApplicationRecord
  belongs_to :questionnaire
  has_many :questions, dependent: :restrict_with_error

  default_scope { order(:position, :created_at) }

  validates :title, presence: true
  validates :position, numericality: { greater_than: 0 }

  before_validation :assign_position, on: :create

  private

  def assign_position
    return if position.present? || questionnaire.blank?

    max_position = questionnaire.sections.unscope(:order).maximum(:position) || 0
    self.position = max_position + 1
  end
end
