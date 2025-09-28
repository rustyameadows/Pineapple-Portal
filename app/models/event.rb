class Event < ApplicationRecord
  has_many :questionnaires, dependent: :destroy
  has_many :questions, through: :questionnaires
  has_many :documents, dependent: :destroy
  has_many :attachments, as: :entity, dependent: :destroy
  has_many :event_links, -> { order(:position, :id) }, dependent: :destroy
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

  scope :active, -> { where(archived_at: nil) }
  scope :archived, -> { where.not(archived_at: nil) }

  validates :name, presence: true

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
end
