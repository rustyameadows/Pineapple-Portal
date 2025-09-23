class Question < ApplicationRecord
  belongs_to :questionnaire
  belongs_to :questionnaire_section
  belongs_to :event

  has_many :attachments, as: :entity, dependent: :destroy

  before_validation :sync_relationships_from_questionnaire

  validate :section_matches_questionnaire

  validates :prompt, presence: true
  validates :response_type, presence: true
  validates :event, presence: true
  validates :position, numericality: { greater_than: 0 }
  validates :position, uniqueness: { scope: :questionnaire_section_id }

  private

  def sync_relationships_from_questionnaire
    return if questionnaire.blank?

    self.event = questionnaire.event
    self.questionnaire_section ||= questionnaire.sections.first
  end

  def section_matches_questionnaire
    return if questionnaire_section.blank? || questionnaire.blank?

    return if questionnaire_section.questionnaire_id == questionnaire_id

    errors.add(:questionnaire_section, "must belong to the questionnaire")
  end
end
