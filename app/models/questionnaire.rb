class Questionnaire < ApplicationRecord
  belongs_to :event
  belongs_to :template_source, class_name: "Questionnaire", optional: true

  has_many :questions, dependent: :destroy
  has_many :attachments, as: :entity, dependent: :destroy

  scope :templates, -> { where(is_template: true) }
  scope :for_event, ->(event_id) { where(event_id: event_id) }

  before_validation :clear_template_source_when_template

  validates :title, presence: true
  validates :template_source_id,
            uniqueness: { scope: :event_id, allow_nil: true }
  validate :template_source_only_for_instances

  def template?
    is_template?
  end

  private

  def clear_template_source_when_template
    self.template_source_id = nil if template?
  end

  def template_source_only_for_instances
    return unless template? && template_source_id.present?

    errors.add(:template_source_id, "must be blank for templates")
  end
end
