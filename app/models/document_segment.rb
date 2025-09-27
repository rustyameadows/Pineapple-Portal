class DocumentSegment < ApplicationRecord
  KINDS = {
    pdf_asset: "pdf_asset",
    html_view: "html_view"
  }.freeze

  belongs_to :document,
             foreign_key: :document_logical_id,
             primary_key: :logical_id
  has_many :dependencies,
           class_name: "DocumentDependency",
           foreign_key: :segment_id,
           inverse_of: :segment,
           dependent: :destroy

  HTML_VIEWS = {
    "event_overview" => {
      label: "Event Overview",
      template: "generated_documents/sections/event_overview",
      description: "Hero block with event dates, venue, and key facts."
    },
    "planning_team" => {
      label: "Planning Team",
      template: "generated_documents/sections/planning_team",
      description: "Roster of planners with contact details."
    },
    "timeline" => {
      label: "Timeline Snapshot",
      template: "generated_documents/sections/timeline",
      description: "Milestone list pulled from the decision calendar."
    }
  }.freeze

  enum :kind, KINDS, validate: true

  scope :ordered, -> { order(:position, :id) }

  validates :document_logical_id, :position, :kind, presence: true
  validates :title, presence: true
  validates :position, numericality: { only_integer: true, greater_than: 0 }
  validates :source_ref, :spec, presence: true
  validate :validate_source_ref_payload

  before_validation :assign_position, on: :create

  class << self
    def html_view?(key)
      HTML_VIEWS.key?(key.to_s)
    end

    def html_view(key)
      HTML_VIEWS[key.to_s]
    end

    def html_view_options
      HTML_VIEWS.map { |key, config| [config[:label], key] }
    end

    def resequence!(document_logical_id)
      transaction do
        ordered.where(document_logical_id: document_logical_id).each_with_index do |segment, index|
          next if segment.position == index + 1

          segment.update_column(:position, index + 1)
        end
      end
    end
  end

  def html_view_key
    return unless html_view?

    source_ref.is_a?(Hash) ? source_ref["view_key"] : nil
  end

  def html_view_config
    self.class.html_view(html_view_key)
  end

  def view_key
    html_view_key
  end

  def pdf_document_id
    return unless pdf_asset?

    source_ref.is_a?(Hash) ? source_ref["document_id"] : nil
  end

  def pdf_logical_id
    return unless pdf_asset?

    source_ref.is_a?(Hash) ? source_ref["logical_id"] : nil
  end

  def display_title
    title.presence || spec.fetch("label", kind.humanize)
  end

  def assign_pdf_document(document)
    self.source_ref = {
      "document_id" => document.id,
      "logical_id" => document.logical_id,
      "version" => document.version,
      "title" => document.title
    }
    self.spec = {
      "label" => document.title,
      "kind" => KINDS[:pdf_asset],
      "document_id" => document.id
    }
    self.title = document.title if title.blank?
  end

  def assign_html_view(view_key, options: {})
    config = self.class.html_view(view_key)
    return unless config

    self.source_ref = {
      "view_key" => view_key,
      "options" => options.presence || {}
    }
    self.spec = {
      "label" => config[:label],
      "kind" => KINDS[:html_view],
      "view_key" => view_key
    }
    self.title = config[:label] if title.blank?
  end

  def move_up!
    sibling = document.segments.where("position < ?", position).order(position: :desc).first
    swap_positions_with!(sibling) if sibling
  end

  def move_down!
    sibling = document.segments.where("position > ?", position).order(position: :asc).first
    swap_positions_with!(sibling) if sibling
  end

  private

  def assign_position
    return if position.present?

    return unless document

    last_position = document.segments.maximum(:position)
    self.position = last_position.present? ? last_position + 1 : 1
  end

  def validate_source_ref_payload
    return if source_ref.blank?

    case kind
    when KINDS[:pdf_asset]
      unless source_ref.is_a?(Hash) && source_ref["logical_id"].present?
        errors.add(:source_ref, "must include a document reference")
      end
    when KINDS[:html_view]
      view_key = source_ref.is_a?(Hash) ? source_ref["view_key"] : nil
      unless self.class.html_view?(view_key)
        errors.add(:source_ref, "must include a valid view key")
      end
    end
  end

  def swap_positions_with!(other)
    return unless other

    DocumentSegment.transaction do
      current_position = position
      update!(position: other.position)
      other.update!(position: current_position)
    end
  end
end
