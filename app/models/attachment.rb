class Attachment < ApplicationRecord
  CONTEXTS = %w[prompt help_text answer other].freeze

  belongs_to :entity, polymorphic: true
  belongs_to :document, optional: true

  enum :context, {
    prompt: "prompt",
    help_text: "help_text",
    answer: "answer",
    other: "other"
  }, validate: true

  validates :context, presence: true
  validates :position, numericality: { greater_than: 0 }
  validate :exactly_one_document_reference

  def resolved_document
    return document if document.present?
    return unless document_logical_id.present?

    Document.latest.find_by(logical_id: document_logical_id)
  end

  private

  def exactly_one_document_reference
    if document.present? && document_logical_id.present?
      errors.add(:base, "Specify either document or document_logical_id, not both")
    elsif document.blank? && document_logical_id.blank?
      errors.add(:base, "Document reference is required")
    end
  end
end
