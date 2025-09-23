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
  has_many :event_calendars, dependent: :destroy
  has_many :calendar_items, through: :event_calendars
  has_many :event_calendar_views, through: :event_calendars

  has_one :run_of_show_calendar,
          -> { where(kind: EventCalendar::KINDS[:master]) },
          class_name: "EventCalendar",
          dependent: :destroy

  scope :active, -> { where(archived_at: nil) }
  scope :archived, -> { where.not(archived_at: nil) }

  validates :name, presence: true

  def archived?
    archived_at.present?
  end
end
