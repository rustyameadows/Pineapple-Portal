class GeneratedPacketPlacement < ApplicationRecord
  belongs_to :document,
             class_name: "Document",
             foreign_key: :document_logical_id,
             primary_key: :logical_id
  belongs_to :source,
             class_name: "GeneratedPacketSource",
             foreign_key: :generated_packet_source_id

  scope :ordered, -> { order(:position, :id) }

  validates :document_logical_id, :position, presence: true
  validates :position, numericality: { only_integer: true, greater_than: 0 }
  validate :prevent_nested_groups

  before_validation :assign_position, on: :create

  delegate :kind,
           :title,
           :display_title,
           :builder_label,
           :html_view?,
           :html_view_config,
           :pdf_asset?,
           :html_view_key,
           :html_options,
           :pdf_document_id,
           :pdf_logical_id,
           :source_ref,
           :spec,
           :cached?,
           :cached_pdf_key,
           :cached_pdf_generated_at,
           :cached_page_count,
           :cached_file_size,
           :last_render_error,
           :render_hash,
           :canonical?,
           :page?,
           :upload?,
           :group?,
           :group_source?,
           :group_document,
           :group_document_logical_id,
           :group_child_count,
           to: :source

  private

  def assign_position
    return if position.present?

    last_position = self.class.where(document_logical_id: document_logical_id).maximum(:position)
    self.position = last_position.present? ? last_position + 1 : 1
  end

  def prevent_nested_groups
    return unless source&.group?
    return unless document&.group_container?

    errors.add(:source, "groups cannot contain other groups")
  end
end
