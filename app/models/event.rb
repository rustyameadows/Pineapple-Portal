class Event < ApplicationRecord
  has_many :questionnaires, dependent: :destroy
  has_many :questions, through: :questionnaires
  has_many :documents, dependent: :destroy
  has_many :attachments, as: :entity, dependent: :destroy
  has_many :event_links, -> { order(:position, :id) }, dependent: :destroy
  has_many :event_vendors,
           -> { order(:position, :id) },
           dependent: :destroy
  has_many :event_venues,
           -> { order(:position, :id) },
           dependent: :destroy
  has_many :payments, dependent: :destroy
  has_many :approvals, dependent: :destroy
  has_many :event_team_members, dependent: :destroy
  has_many :team_members, through: :event_team_members, source: :user
  has_many :planner_team_members,
           -> { where(member_role: EventTeamMember::TEAM_ROLES[:planner]) },
           class_name: "EventTeamMember",
           inverse_of: :event
  has_many :client_team_members,
           -> { where(member_role: EventTeamMember::TEAM_ROLES[:client]) },
           class_name: "EventTeamMember",
           inverse_of: :event
  has_many :client_users, through: :client_team_members, source: :user
  has_many :event_calendars, dependent: :destroy
  has_many :calendar_items, through: :event_calendars
  has_many :event_calendar_views, through: :event_calendars

  has_one :run_of_show_calendar,
          -> { where(kind: EventCalendar::KINDS[:master]) },
          class_name: "EventCalendar",
          dependent: :destroy

  belongs_to :event_photo_document,
             class_name: "Document",
             optional: true

  validate :event_photo_document_must_be_image
  before_validation :sanitize_planning_link_tokens
  validate :planning_link_keys_must_be_known

  PlanningLinkEntry = Struct.new(:token, :kind, :record, keyword_init: true)

  scope :active, -> { where(archived_at: nil) }
  scope :archived, -> { where.not(archived_at: nil) }

  validates :name, presence: true
  validates :portal_slug, uniqueness: true, allow_blank: true

  before_validation :normalize_portal_slug

  def planning_link_tokens
    tokens = normalize_planning_link_tokens(stored_planning_link_tokens)
    tokens = default_planning_link_tokens if tokens.blank?

    tokens = prune_invalid_planning_link_tokens(tokens)

    planning_event_link_tokens.each do |token|
      tokens << token unless tokens.include?(token)
    end

    tokens
  end

  def planning_link_tokens=(value)
    store_planning_link_tokens(value)
  end

  def planning_link_keys
    tokens = normalize_planning_link_tokens(stored_planning_link_tokens)
    tokens = default_planning_link_tokens if tokens.blank?

    tokens
      .select { |token| PlanningLinkToken.built_in?(token) }
      .map { |token| PlanningLinkToken.token_value(token) }
  end

  def planning_link_enabled?(key)
    planning_link_keys.include?(key.to_s)
  end

  def enable_planning_link(key)
    tokens = planning_link_tokens.dup
    token = PlanningLinkToken.built_in(key)
    tokens << token unless tokens.include?(token)
    store_planning_link_tokens(tokens)
  end

  def disable_planning_link(key)
    tokens = planning_link_tokens.reject { |token| PlanningLinkToken.built_in?(token, key) }
    store_planning_link_tokens(tokens)
  end

  def append_planning_event_link_token(link)
    token = PlanningLinkToken.event_link(link.id)
    tokens = planning_link_tokens.dup
    tokens << token unless tokens.include?(token)
    store_planning_link_tokens(tokens)
  end

  def remove_planning_event_link_token(link)
    token = PlanningLinkToken.event_link(link.id)
    tokens = planning_link_tokens.reject { |existing| existing == token }
    store_planning_link_tokens(tokens)
  end

  def move_planning_link_token(token, direction)
    tokens = planning_link_tokens.dup
    index = tokens.index(token)
    return false unless index

    case direction
    when :up
      return false if index.zero?
      tokens[index - 1], tokens[index] = tokens[index], tokens[index - 1]
    when :down
      return false if index == tokens.length - 1
      tokens[index + 1], tokens[index] = tokens[index], tokens[index + 1]
    else
      return false
    end

    store_planning_link_tokens(tokens)
    true
  end

  def ordered_planning_link_entries
    mapping = planning_link_token_mapping

    planning_link_tokens.filter_map do |token|
      record = mapping[token]
      next unless record

      kind = PlanningLinkToken.built_in?(token) ? :built_in : :event_link
      PlanningLinkEntry.new(token: token, kind: kind, record: record)
    end
  end

  def ordered_planning_links
    ordered_planning_link_entries.map(&:record)
  end

  def archived?
    archived_at.present?
  end

  private

  def event_photo_document_must_be_image
    return if event_photo_document_id.blank?

    unless event_photo_document && event_photo_document.event_id == id
      errors.add(:event_photo_document, "must belong to this event")
      return
    end

    content_type = event_photo_document.content_type.to_s
    unless content_type.start_with?("image/")
      errors.add(:event_photo_document, "must be an image file")
    end
  end

  def normalize_portal_slug
    return if portal_slug.nil?

    normalized = portal_slug.to_s.strip
    normalized = normalized.parameterize if normalized.present?
    self.portal_slug = normalized.presence
  end

  def stored_planning_link_tokens
    self[:planning_link_keys] || []
  end

  def normalize_planning_link_tokens(value)
    Array(value).map { |token| standardize_planning_link_token(token) }.compact.uniq
  end

  def planning_link_keys_must_be_known
    unrecognized_built_in_keys = stored_planning_link_tokens
                                   .map { |token| standardize_planning_link_token(token) }
                                   .compact
                                   .select { |token| PlanningLinkToken.built_in?(token) }
                                   .map { |token| PlanningLinkToken.token_value(token) }
                                   .reject { |key| ClientPortal::PlanningLinks.built_in_keys.include?(key) }

    return if unrecognized_built_in_keys.empty?

    errors.add(:planning_link_keys, "contains unknown links: #{unrecognized_built_in_keys.join(', ')}")
  end

  def sanitize_planning_link_tokens
    tokens = normalize_planning_link_tokens(stored_planning_link_tokens)

    planning_event_link_tokens.each do |token|
      tokens << token unless tokens.include?(token)
    end

    self[:planning_link_keys] = tokens
  end

  def default_planning_link_tokens
    ClientPortal::PlanningLinks.default_keys.map { |key| PlanningLinkToken.built_in(key) }
  end

  def planning_event_link_tokens
    event_links.planning.ordered.pluck(:id).map do |id|
      PlanningLinkToken.event_link(id)
    end
  end

  def prune_invalid_planning_link_tokens(tokens)
    normalize_planning_link_tokens(tokens).select do |token|
      PlanningLinkToken.valid?(token, event: self)
    end
  end

  def planning_link_token_mapping
    built_in_links = ClientPortal::PlanningLinks.built_in_links_for(self)
    mapping = built_in_links.to_h do |link|
      [PlanningLinkToken.built_in(link.key), link]
    end

    event_links.planning.ordered.each do |link|
      mapping[PlanningLinkToken.event_link(link.id)] = link
    end

    mapping
  end

  def store_planning_link_tokens(tokens)
    self[:planning_link_keys] = normalize_planning_link_tokens(tokens)
  end

  def standardize_planning_link_token(token)
    token = token.to_s.strip
    return if token.blank?

    return token if token.include?(":")

    PlanningLinkToken.built_in(token)
  end
end
