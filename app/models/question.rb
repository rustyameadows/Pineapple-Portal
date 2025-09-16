class Question < ApplicationRecord
  belongs_to :questionnaire
  belongs_to :event
  has_many :attachments, as: :entity, dependent: :destroy

  before_validation :sync_event_from_questionnaire
  validate :answers_only_on_instances

  validates :prompt, presence: true
  validates :response_type, presence: true
  validates :event, presence: true
  validates :position, numericality: { greater_than: 0 }

  private

  def sync_event_from_questionnaire
    self.event = questionnaire&.event
  end

  def answers_only_on_instances
    return if questionnaire.blank?
    return unless questionnaire.template?

    if answer_value.present? || answer_raw.present? || answered_at.present?
      errors.add(:base, "Template questions cannot store answers")
    end
  end
end
