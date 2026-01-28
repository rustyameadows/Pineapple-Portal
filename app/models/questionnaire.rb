class Questionnaire < ApplicationRecord
  belongs_to :event
  belongs_to :template_source, class_name: "Questionnaire", optional: true

  has_many :sections, -> { order(:position, :created_at) }, class_name: "QuestionnaireSection", dependent: :destroy, inverse_of: :questionnaire
  has_many :questions, dependent: :destroy
  has_many :attachments, as: :entity, dependent: :destroy

  accepts_nested_attributes_for :sections, allow_destroy: true

  scope :templates, -> { where(is_template: true) }
  scope :for_event, ->(event_id) { where(event_id: event_id) }
  scope :client_visible, -> { where(client_visible: true) }
  scope :in_progress, -> { where(status: "in_progress") }
  scope :finished, -> { where(status: "finished") }

  STATUSES = {
    in_progress: "in_progress",
    finished: "finished"
  }.freeze

  before_validation :clear_template_source_when_template
  after_create_commit :ensure_default_section
  after_initialize :set_default_status, if: :new_record?

  validates :title, presence: true
  validates :template_source_id,
            uniqueness: { scope: :event_id, allow_nil: true }
  validate :template_source_only_for_instances
  validates :status, inclusion: { in: STATUSES.values }

  def template?
    is_template?
  end

  def finished?
    status == STATUSES[:finished]
  end

  def in_progress?
    status == STATUSES[:in_progress]
  end

  def duplicate_to_event!(event, title: nil)
    transaction do
      new_questionnaire = event.questionnaires.create!(
        title: title.presence || self.title,
        description: description,
        client_visible: client_visible,
        status: STATUSES[:in_progress],
        is_template: false
      )
      copy_sections_and_questions!(new_questionnaire)
      new_questionnaire
    end
  end

  def append_to!(destination_questionnaire)
    transaction do
      section_offset = destination_questionnaire.sections.unscope(:order).maximum(:position) || 0
      copy_sections_and_questions!(destination_questionnaire, section_position_offset: section_offset)
      destination_questionnaire
    end
  end

  private

  def clear_template_source_when_template
    self.template_source_id = nil if template?
  end

  def template_source_only_for_instances
    return unless template? && template_source_id.present?

    errors.add(:template_source_id, "must be blank for templates")
  end

  def ensure_default_section
    return if sections.exists?

    sections.create!(title: "Section 1")
  end

  def set_default_status
    self.status ||= STATUSES[:in_progress]
  end

  def copy_sections_and_questions!(destination_questionnaire, section_position_offset: 0)
    sections.reorder(:position, :created_at).each_with_index do |section, index|
      new_section = destination_questionnaire.sections.create!(
        title: section.title,
        helper_text: section.helper_text,
        position: section_position_offset + index + 1
      )

      section.questions.reorder(:position, :created_at).each do |question|
        new_question = destination_questionnaire.questions.create!(
          questionnaire_section: new_section,
          event: destination_questionnaire.event,
          prompt: question.prompt,
          help_text: question.help_text,
          response_type: question.response_type,
          position: question.position,
          answer_value: nil,
          answer_raw: {},
          answered_at: nil
        )
        copy_question_attachments!(question, new_question)
      end
    end
  end

  def copy_question_attachments!(source_question, destination_question)
    source_question.attachments.where.not(context: :answer).reorder(:position).each do |attachment|
      attrs = {
        context: attachment.context,
        position: attachment.position
      }

      if attachment.document_id.present?
        attrs[:document_id] = attachment.document_id
      elsif attachment.document_logical_id.present?
        attrs[:document_logical_id] = attachment.document_logical_id
      else
        next
      end

      destination_question.attachments.create!(attrs)
    end
  end
end
