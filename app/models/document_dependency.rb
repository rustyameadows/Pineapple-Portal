class DocumentDependency < ApplicationRecord
  belongs_to :segment, class_name: "DocumentSegment"

  validates :document_logical_id, :entity_type, :entity_id, presence: true
end
