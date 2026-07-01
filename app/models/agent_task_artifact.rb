class AgentTaskArtifact < ApplicationRecord
  SOURCE_KINDS = {
    source_document: "source_document",
    generated_artifact: "generated_artifact"
  }.freeze

  belongs_to :agent_task
  belongs_to :document, optional: true

  attribute :source_kind, :string
  enum :source_kind, SOURCE_KINDS, validate: true

  validates :filename, presence: true
  validates :position, numericality: { greater_than: 0 }
  validates :size_bytes, numericality: { greater_than: 0 }, allow_nil: true
end
