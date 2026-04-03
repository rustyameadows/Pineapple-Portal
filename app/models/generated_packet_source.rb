class GeneratedPacketSource < ApplicationRecord
  KINDS = DocumentSegment::KINDS

  CATEGORIES = {
    canonical: "canonical",
    page: "page",
    upload: "upload"
  }.freeze

  CANONICAL_KEYS = {
    event_overview: "event_overview",
    planning_team: "planning_team",
    run_of_show: "run_of_show",
    family_timeline: "family_timeline",
    production_timeline: "production_timeline",
    wedding_party_reference: "wedding_party_reference"
  }.freeze

  CANONICAL_CONFIGS = {
    CANONICAL_KEYS[:event_overview] => {
      label: "Event Overview",
      description: "Shared event overview page for this event.",
      view_key: DocumentSegment::EVENT_OVERVIEW_VIEW_KEY,
      options: lambda { |_event|
        { "body_markdown" => DocumentSegment.default_body_markdown_for(DocumentSegment::EVENT_OVERVIEW_VIEW_KEY) }
      }
    },
    CANONICAL_KEYS[:planning_team] => {
      label: "Planning Team",
      description: "Shared planning team page for this event.",
      view_key: "planning_team",
      options: ->(_event) { {} }
    },
    CANONICAL_KEYS[:run_of_show] => {
      label: "Run of Show",
      description: "Shared full run-of-show timeline for this event.",
      view_key: DocumentSegment::RUN_OF_SHOW_VIEW_KEY,
      options: ->(_event) { default_timeline_options }
    },
    CANONICAL_KEYS[:family_timeline] => {
      label: "Family Timeline",
      description: "Shared family-focused timeline for this event.",
      view_key: DocumentSegment::TIMELINE_VIEW_KEY,
      options: lambda { |event|
        default_timeline_options.merge("view_ref" => Documents::Generated::DefaultTimelineViews.ensure_view!(event, "Family Timeline").id.to_s)
      }
    },
    CANONICAL_KEYS[:production_timeline] => {
      label: "Production Timeline",
      description: "Shared production-focused timeline for this event.",
      view_key: DocumentSegment::TIMELINE_VIEW_KEY,
      options: lambda { |event|
        default_timeline_options.merge("view_ref" => Documents::Generated::DefaultTimelineViews.ensure_view!(event, "Production Timeline").id.to_s)
      }
    },
    CANONICAL_KEYS[:wedding_party_reference] => {
      label: "Wedding Party Reference",
      description: "Placeholder for the upcoming wedding party reference packet page.",
      view_key: DocumentSegment::TEXT_PAGE_VIEW_KEY,
      options: lambda { |_event|
        {
          "body_markdown" => <<~MARKDOWN.strip
            ## Wedding Party Reference

            This shared page is ready for future wedding party reference content.
          MARKDOWN
        }
      }
    }
  }.freeze

  belongs_to :event
  has_many :packet_placements,
           -> { order(:position, :id) },
           class_name: "GeneratedPacketPlacement",
           dependent: :destroy

  enum :kind, KINDS, validate: true

  validates :event_id, :kind, :title, :source_ref, :spec, :source_category, presence: true
  validates :canonical_key, uniqueness: { scope: :event_id }, allow_nil: true
  validate :validate_source_ref_payload

  before_save :reset_cached_metadata, if: :content_affecting_change?

  class << self
    def html_view?(key)
      DocumentSegment.html_view?(key)
    end

    def html_view(key)
      DocumentSegment.html_view(key)
    end

    def default_body_markdown_for(view_key)
      DocumentSegment.default_body_markdown_for(view_key)
    end

    def page_view_options
      page_view_keys.map do |view_key|
        config = html_view(view_key)
        [config[:label], view_key]
      end
    end

    def page_view_keys
      [DocumentSegment::TEXT_PAGE_VIEW_KEY, "section_break", "cover_sheet"]
    end

    def canonical_config(key)
      CANONICAL_CONFIGS[key.to_s]
    end

    def ensure_canonical_sources_for_event!(event)
      CANONICAL_CONFIGS.keys.index_with do |key|
        ensure_canonical!(event, key)
      end
    end

    def ensure_canonical!(event, key)
      canonical_key = key.to_s
      config = canonical_config(canonical_key)
      raise ArgumentError, "Unknown canonical key: #{canonical_key}" unless config

      event.generated_packet_sources.find_or_initialize_by(canonical_key: canonical_key).tap do |source|
        next if source.persisted?

        source.source_category = CATEGORIES[:canonical]
        source.kind = KINDS[:html_view]
        source.title = config[:label]
        source.assign_html_view(config[:view_key], options: config[:options].call(event))
        source.save!
      end
    end

    def find_or_create_upload_source!(event, document, title: nil)
      logical_id = document.logical_id
      desired_title = title.presence || document.title

      existing = event.generated_packet_sources
                      .where(source_category: CATEGORIES[:upload], kind: KINDS[:pdf_asset], title: desired_title)
                      .detect { |source| source.pdf_logical_id == logical_id }
      return existing if existing

      event.generated_packet_sources.new(
        source_category: CATEGORIES[:upload],
        kind: KINDS[:pdf_asset],
        title: desired_title
      ).tap do |source|
        source.assign_pdf_document(document)
        source.save!
      end
    end

    def build_page_source(event:, view_key:, title:, options: {})
      event.generated_packet_sources.new(
        source_category: CATEGORIES[:page],
        kind: KINDS[:html_view],
        title: title.presence || html_view(view_key).fetch(:label)
      ).tap do |source|
        source.assign_html_view(view_key, options: options)
      end
    end

    def default_timeline_options
      {
        "show_location" => true,
        "show_vendor" => true,
        "show_team_members" => true
      }
    end
  end

  def canonical?
    source_category == CATEGORIES[:canonical]
  end

  def page?
    source_category == CATEGORIES[:page]
  end

  def upload?
    source_category == CATEGORIES[:upload]
  end

  def html_view?
    kind == KINDS[:html_view]
  end

  def pdf_asset?
    kind == KINDS[:pdf_asset]
  end

  def html_view_key
    return unless html_view?

    source_ref.is_a?(Hash) ? source_ref["view_key"] : nil
  end

  def view_key
    html_view_key
  end

  def html_view_config
    self.class.html_view(html_view_key)
  end

  def html_options
    return {} unless html_view?

    options = source_ref.is_a?(Hash) ? source_ref["options"] : nil
    options.is_a?(Hash) ? options.deep_dup : {}
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

  def builder_label
    return "Canonical" if canonical?
    return "Page" if page?
    return "Upload" if upload?

    "Segment"
  end

  def cached?
    cached_pdf_key.present? && cached_pdf_generated_at.present?
  end

  def cache_stale?(current_hash)
    render_hash != current_hash
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

  private

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

  def content_affecting_change?
    new_record? ||
      will_save_change_to_kind? ||
      will_save_change_to_title? ||
      will_save_change_to_source_ref? ||
      will_save_change_to_spec? ||
      will_save_change_to_canonical_key? ||
      will_save_change_to_source_category?
  end

  def reset_cached_metadata
    self.render_hash = nil
    self.cached_pdf_key = nil
    self.cached_pdf_generated_at = nil
    self.cached_page_count = nil
    self.cached_file_size = nil
    self.last_render_error = nil
  end
end
