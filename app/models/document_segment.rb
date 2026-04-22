class DocumentSegment < ApplicationRecord
  KINDS = {
    pdf_asset: "pdf_asset",
    html_view: "html_view"
  }.freeze

  TIMELINE_VIEW_KEY = "timeline".freeze
  RUN_OF_SHOW_VIEW_KEY = "run_of_show_timeline".freeze
  TEXT_PAGE_VIEW_KEY = "text_page".freeze
  EVENT_OVERVIEW_VIEW_KEY = "event_overview".freeze
  VENDOR_CONTACTS_VIEW_KEY = "vendor_contacts".freeze
  WEDDING_PARTY_REFERENCE_VIEW_KEY = "wedding_party_reference".freeze
  SYSTEM_MANAGED_VIEW_KEYS = [
    EVENT_OVERVIEW_VIEW_KEY,
    VENDOR_CONTACTS_VIEW_KEY,
    WEDDING_PARTY_REFERENCE_VIEW_KEY
  ].freeze
  SHARED_PDF_TEMPLATE_VERSION = "packet-base-v2".freeze
  EVENT_OVERVIEW_TEMPLATE_VERSION = "packet-sheet-v9".freeze
  VENDOR_CONTACTS_TEMPLATE_VERSION = "packet-sheet-v1".freeze
  WEDDING_PARTY_REFERENCE_TEMPLATE_VERSION = "packet-sheet-v6".freeze
  EVENT_OVERVIEW_DEFAULT_BODY_MARKDOWN = <<~MARKDOWN.freeze
    ### Important Information

    **Date** | Sunday, August 31, 2025
    **Ceremony** | La Caille
    **Reception** | La Caille
    **Guest Count** | 171 guests


    **Bride** | Hannah Isakowitz
    **Groom** | Dan Greener
    **Parents of the Bride** | Missy and Mark Isakowitz
    **Parents of the Groom** | Ruth and Jeﬀ Greener


    **Attire** | Black Tie
    **Color Palette** | White, Ivory, Cool Blue, Sage, Pine & Touches of Pastels

    ### Timeline

    #### Friday, August 29

    :::columns
    :::column
    **Ceremony Rehearsal**  
    Le Meridien - Pierce Arrow Board Room  
    5:30 PM  
    :::
    :::column
    **Rehearsal Dinner**  
    Provisions  
    7:00 PM to 10:00 PM
    :::
    :::

    #### Saturday, August 30

    **Welcome Party**  
    Salt & Olive  
    6:00 PM to 9:00 PM

    #### Sunday, August 31
    :::columns
    :::column
    **Ceremony**  
    La Caille  
    4:30 PM to 5:00 PM  

    **Dinner & Dancing**  
    La Caille  
    6:00 PM to 10:00 PM  
    :::
    :::column
    **Cocktails**  
    La Caille  
    5:00 PM to 6:00 PM  

    **After Party**  
    Le Meridien - Van Ryder  
    10:00 PM to 12:00 AM
    :::
    :::

    ### Planner Contact

    **Lead Planner:** Jordan Lee  
    **Cell:** (555) 010-2200  
    **Email:** jordan@pineapple.test  

    **Assistant Planner:** Sam Rivera  
    **Cell:** (555) 010-2233  
    **Email:** sam@pineapple.test

    ### Vendor Contacts

    :::columns
    :::column
    **Venue**
    :::
    :::column
    **Grand Ballroom** - Maria Stone  
      (555) 777-8888 | maria@grandballroom.test | @grandballroom

    ---


    **Grand Ballroom** - Maria Stone  
      (555) 777-8888 | maria@grandballroom.test | @grandballroom
    :::
    :::
    ---
    :::columns
    :::column
    **Catering**
    :::
    :::column
    **Sunshine Catering** - Leo Park  
      (555) 123-4567 | leo@sunshine.test | @sunshinecatering
    :::
    :::
    ---
    :::columns
    :::column
    **Floral**
    :::
    :::column
    **Bloom Studio** - Ana Flores  
      (555) 990-1133 | ana@bloomstudio.test | @bloomstudio
    :::
    :::
    ---
    :::columns
    :::column
    **Photo + Video**
    :::
    :::column
    **Northlight Films** - Chris Lane  
      (555) 331-4400 | chris@northlight.test | @northlightfilms


    ---

    **Bright Lights Production** - Devon Reed  
      (555) 998-1200 | devon@brightlights.test | @brightlights
    :::
    :::
    ---
    :::columns
    :::column
    **Transportation**
    :::
    :::column
    **City Shuttle Co.** - Taylor Brooks  
      (555) 222-8899 | dispatch@cityshuttle.test | @cityshuttle
    :::
    :::

    ### Social Media

    No photos or videos of the couple, their guests, or any wedding details (including setup and behind-the-scenes) may be posted on social media before or during the wedding on any public-facing platforms. Pineapple Productions will make the first public social media post on our main feed as a collaborative eﬀort, inviting the key vendors involved. After Pineapple Productions has made this initial post are vendors welcome to share their own images and videos, always ensuring they tag all other relevant vendors who contributed to the wedding.

    ### Parking

    See La Caille property map for delivery details. Please park vehicles in lot 3B once finished unloading. Self parking is available at all other event locations.
  MARKDOWN

  belongs_to :document,
             foreign_key: :document_logical_id,
             primary_key: :logical_id
  has_many :dependencies,
           class_name: "DocumentDependency",
           foreign_key: :segment_id,
           inverse_of: :segment,
           dependent: :destroy

  HTML_VIEWS = {
    EVENT_OVERVIEW_VIEW_KEY => {
      label: "Event Overview",
      template: "generated_documents/sections/event_overview",
      description: "Structured event overview powered by live event and contact data."
    },
    VENDOR_CONTACTS_VIEW_KEY => {
      label: "Vendor Contacts",
      template: "generated_documents/sections/vendor_contacts",
      description: "Simple vendor contact table powered by live planner and vendor data."
    },
    WEDDING_PARTY_REFERENCE_VIEW_KEY => {
      label: "Wedding Party Reference",
      template: "generated_documents/sections/wedding_party_reference",
      description: "Structured wedding party reference sheet with packet-ready planning details."
    },
    "planning_team" => {
      label: "Planning Team Directory",
      template: "generated_documents/sections/planning_team",
      description: "Roster of planners with contact details."
    },
    TIMELINE_VIEW_KEY => {
      label: "Timeline Snapshot",
      template: "generated_documents/sections/timeline",
      description: "Filtered milestone list pulled from a run-of-show view."
    },
    RUN_OF_SHOW_VIEW_KEY => {
      label: "Run of Show",
      template: "generated_documents/sections/timeline",
      description: "Full run-of-show schedule from the master calendar."
    },
    TEXT_PAGE_VIEW_KEY => {
      label: "Text Page",
      template: "generated_documents/sections/text_page",
      description: "General-purpose formatted text section using Markdown syntax."
    },
    "section_break" => {
      label: "Section Break",
      template: "generated_documents/sections/section_break",
      description: "Full-bleed divider page with centered title.",
      options: {
        margin: { top: "0", bottom: "0", left: "0", right: "0" }
      }
    },
    "cover_sheet" => {
      label: "Cover Sheet",
      template: "generated_documents/sections/cover_sheet",
      description: "Single-page cover with branding, event title, and document name.",
      options: {
        margin: { top: "0", bottom: "0", left: "0", right: "0" }
      }
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
  before_save :reset_cached_metadata, if: :content_affecting_change?

  class << self
    def html_view?(key)
      HTML_VIEWS.key?(key.to_s)
    end

    def html_view(key)
      HTML_VIEWS[key.to_s]
    end

    def default_body_markdown_for(view_key)
      ""
    end

    def html_view_options
      HTML_VIEWS.map { |key, config| [config[:label], key] }
    end

    def shared_pdf_template_version
      SHARED_PDF_TEMPLATE_VERSION
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

  def cached?
    cached_pdf_key.present? && cached_pdf_generated_at.present?
  end

  def cache_stale?(current_hash)
    render_hash != current_hash
  end

  def cache_storage_path(hash = render_hash)
    return unless hash.present?

    "segments/#{hash}.pdf"
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
    return if position <= 1

    old_position = position
    relation = DocumentSegment.where(document_logical_id: document_logical_id)

    DocumentSegment.transaction do
      temp_position = relation.maximum(:position).to_i + 1
      update_columns(position: temp_position)
      relation.where(position: old_position - 1).update_all(position: old_position)
      update_columns(position: old_position - 1)
    end
  end

  def move_down!
    relation = DocumentSegment.where(document_logical_id: document_logical_id)
    max_position = relation.maximum(:position).to_i
    return if position >= max_position

    old_position = position

    DocumentSegment.transaction do
      temp_position = max_position + 1
      update_columns(position: temp_position)
      relation.where(position: old_position + 1).update_all(position: old_position)
      update_columns(position: old_position + 1)
    end
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

  def content_affecting_change?
    new_record? ||
      will_save_change_to_kind? ||
      will_save_change_to_title? ||
      will_save_change_to_source_ref?
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
