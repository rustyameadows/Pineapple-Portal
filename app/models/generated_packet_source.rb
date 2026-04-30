class GeneratedPacketSource < ApplicationRecord
  KINDS = DocumentSegment::KINDS.merge(
    group: "group"
  ).freeze

  CATEGORIES = {
    canonical: "canonical",
    page: "page",
    upload: "upload",
    group: "group"
  }.freeze

  CANONICAL_KEYS = {
    event_overview: "event_overview",
    planning_team: "planning_team",
    vendor_contacts: "vendor_contacts",
    run_of_show: "run_of_show",
    family_timeline: "family_timeline",
    photo_video_timeline: "photo_video_timeline",
    production_timeline: "production_timeline",
    hair_makeup_timeline: "hair_makeup_timeline",
    wedding_party_reference: "wedding_party_reference"
  }.freeze
  CUSTOM_TIMELINE_CANONICAL_KEY_PREFIX = "custom_timeline_view:".freeze

  CANONICAL_CONFIGS = {
    CANONICAL_KEYS[:event_overview] => {
      label: "Event Overview",
      description: "Shared event overview page for this event.",
      view_key: DocumentSegment::EVENT_OVERVIEW_VIEW_KEY,
      options: ->(_event) { {} }
    },
    CANONICAL_KEYS[:planning_team] => {
      label: "Planning Team Directory",
      description: "Shared planning team page for this event.",
      view_key: "planning_team",
      options: ->(_event) { {} }
    },
    CANONICAL_KEYS[:vendor_contacts] => {
      label: "Vendor Contacts",
      description: "Shared vendor contacts page for this event.",
      view_key: DocumentSegment::VENDOR_CONTACTS_VIEW_KEY,
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
    CANONICAL_KEYS[:photo_video_timeline] => {
      label: "Photo / Video Timeline",
      description: "Shared photo and video timeline for this event.",
      view_key: DocumentSegment::TIMELINE_VIEW_KEY,
      options: lambda { |event|
        default_timeline_options.merge("view_ref" => Documents::Generated::DefaultTimelineViews.ensure_view!(event, "Photo / Video Timeline").id.to_s)
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
    CANONICAL_KEYS[:hair_makeup_timeline] => {
      label: "Hair & Makeup Timeline",
      description: "Shared hair and makeup timeline for this event.",
      view_key: DocumentSegment::TIMELINE_VIEW_KEY,
      options: lambda { |event|
        default_timeline_options.merge("view_ref" => Documents::Generated::DefaultTimelineViews.ensure_view!(event, "Hair & Makeup Timeline").id.to_s)
      }
    },
    CANONICAL_KEYS[:wedding_party_reference] => {
      label: "Wedding Party Reference",
      description: "Shared wedding party reference sheet for this event.",
      view_key: DocumentSegment::WEDDING_PARTY_REFERENCE_VIEW_KEY,
      options: ->(_event) { default_wedding_party_reference_options }
    }
  }.freeze

  belongs_to :event
  has_many :packet_placements,
           -> { order(:position, :id) },
           class_name: "GeneratedPacketPlacement",
           dependent: :destroy

  scope :group_sources, -> { where(source_category: CATEGORIES[:group], kind: KINDS[:group]) }

  validates :event_id, :kind, :title, :source_ref, :spec, :source_category, presence: true
  validates :kind, inclusion: { in: KINDS.values }
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

    def group_view_options
      []
    end

    def canonical_config(key)
      CANONICAL_CONFIGS[key.to_s]
    end

    def ensure_canonical_sources_for_event!(event)
      built_in_sources = CANONICAL_CONFIGS.keys.index_with do |key|
        ensure_canonical!(event, key)
      end
      custom_sources = ensure_custom_timeline_sources_for_event!(event)

      built_in_sources.merge(custom_sources)
    end

    def ensure_canonical!(event, key)
      canonical_key = key.to_s
      config = canonical_config(canonical_key)
      raise ArgumentError, "Unknown canonical key: #{canonical_key}" unless config

      event.generated_packet_sources.find_or_initialize_by(canonical_key: canonical_key).tap do |source|
        sync_canonical_source!(source, canonical_key:, config:, event:)
      end
    end

    def available_canonical_sources_for_event(event)
      live_custom_keys = custom_timeline_views_for_event(event).map { |view| custom_timeline_canonical_key(view) }

      event.generated_packet_sources
           .where(source_category: CATEGORIES[:canonical])
           .order(:title, :id)
           .select do |source|
             !custom_timeline_canonical_key?(source.canonical_key) || live_custom_keys.include?(source.canonical_key)
           end
    end

    def custom_timeline_canonical_key(view_or_id)
      id = view_or_id.respond_to?(:id) ? view_or_id.id : view_or_id
      "#{CUSTOM_TIMELINE_CANONICAL_KEY_PREFIX}#{id}"
    end

    def custom_timeline_canonical_key?(key)
      key.to_s.start_with?(CUSTOM_TIMELINE_CANONICAL_KEY_PREFIX)
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

    def find_or_create_group_source!(event, document)
      source = event.generated_packet_sources.group_sources.find_by("source_ref ->> 'logical_id' = ?", document.logical_id)
      source ||= event.generated_packet_sources.new(
        source_category: CATEGORIES[:group],
        kind: KINDS[:group]
      )

      source.source_category = CATEGORIES[:group]
      source.kind = KINDS[:group]
      source.assign_group_document(document)
      source.save! if source.new_record? || source.changed?
      source
    end

    def default_timeline_options
      {
        "show_location" => true,
        "show_vendor" => true,
        "show_team_members" => true
      }
    end

    def default_wedding_party_reference_options
      {
        "timeline_mode" => "auto",
        "timeline_tag_ids" => []
      }
    end

    private

    def ensure_custom_timeline_sources_for_event!(event)
      custom_timeline_views_for_event(event).index_with do |view|
        ensure_custom_timeline_source!(event, view)
      end
    end

    def ensure_custom_timeline_source!(event, view)
      canonical_key = custom_timeline_canonical_key(view)

      event.generated_packet_sources.find_or_initialize_by(canonical_key: canonical_key).tap do |source|
        existing_options = source.html_view_key == DocumentSegment::TIMELINE_VIEW_KEY ? source.html_options.stringify_keys : {}
        options = default_timeline_options.deep_merge(existing_options).merge("view_ref" => view.id.to_s)

        source.source_category = CATEGORIES[:canonical]
        source.kind = KINDS[:html_view]
        source.canonical_key = canonical_key
        source.assign_html_view(DocumentSegment::TIMELINE_VIEW_KEY, options: options)
        source.title = view.name
        source.save! if source.new_record? || source.changed?
      end
    end

    def custom_timeline_views_for_event(event)
      calendar = event.run_of_show_calendar
      return [] unless calendar

      calendar.event_calendar_views.order(:name, :id).reject do |view|
        default_timeline_view_name?(view.name)
      end
    end

    def default_timeline_view_name?(name)
      default_timeline_view_names.include?(name.to_s.strip.downcase)
    end

    def default_timeline_view_names
      @default_timeline_view_names ||= RunOfShowDefaultViews::VIEWS.map { |view| view[:name].to_s.strip.downcase }
    end

    def sync_canonical_source!(source, canonical_key:, config:, event:)
      source.source_category = CATEGORIES[:canonical]
      source.kind = KINDS[:html_view]
      source.canonical_key = canonical_key
      source.title = config[:label] if source.title.blank?
      existing_options = source.html_view_key == config[:view_key] ? source.html_options.stringify_keys : {}
      default_options = config[:options].call(event).stringify_keys
      source.assign_html_view(config[:view_key], options: default_options.deep_merge(existing_options))
      source.save! if source.new_record? || source.changed?
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

  def group_source?
    source_category == CATEGORIES[:group]
  end

  def html_view?
    kind == KINDS[:html_view]
  end

  def pdf_asset?
    kind == KINDS[:pdf_asset]
  end

  def group?
    kind == KINDS[:group]
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

  def group_document_logical_id
    return unless group?

    source_ref.is_a?(Hash) ? source_ref["logical_id"] : nil
  end

  def group_document
    return unless group_document_logical_id.present?

    event.documents.generated.group_containers.where(logical_id: group_document_logical_id).where(storage_uri: nil).first ||
      event.documents.generated.group_containers.where(logical_id: group_document_logical_id).order(version: :asc).first
  end

  def group_child_count
    return 0 unless group?

    group_document&.packet_placements&.count.to_i
  end

  def display_title
    return group_document.title if group? && group_document&.title.present?

    title.presence || spec.fetch("label", kind.humanize)
  end

  def builder_label
    return "Canonical" if canonical?
    return "Page" if page?
    return "Upload" if upload?
    return "Group" if group?

    "Segment"
  end

  def cached?
    cached_pdf_key.present? && cached_pdf_generated_at.present?
  end

  def cache_stale?(current_hash)
    render_hash != current_hash
  end

  def clear_cached_render!
    update_columns( # rubocop:disable Rails/SkipsModelValidations
      render_hash: nil,
      cached_pdf_key: nil,
      cached_pdf_generated_at: nil,
      cached_page_count: nil,
      cached_file_size: nil,
      last_render_error: nil
    )
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

  def assign_group_document(document)
    self.source_ref = {
      "logical_id" => document.logical_id,
      "title" => document.title
    }
    self.spec = {
      "label" => document.title,
      "kind" => KINDS[:group],
      "logical_id" => document.logical_id
    }
    self.title = document.title
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
    when KINDS[:group]
      logical_id = source_ref.is_a?(Hash) ? source_ref["logical_id"] : nil
      unless logical_id.present?
        errors.add(:source_ref, "must include a group reference")
        return
      end

      document = event&.documents&.generated&.group_containers&.find_by(logical_id: logical_id)
      errors.add(:source_ref, "must reference a group in this event") unless document
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
