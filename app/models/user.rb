class User < ApplicationRecord
  ROLES = {
    planner: "planner",
    client: "client",
    admin: "admin"
  }.freeze

  before_validation :normalize_email

  has_secure_password

  has_many :event_team_members, dependent: :destroy
  has_many :events_as_team_member, through: :event_team_members, source: :event
  has_many :calendar_item_team_members, dependent: :destroy
  has_many :calendar_items_as_team_member, through: :calendar_item_team_members, source: :calendar_item

  attribute :role, :string
  enum :role, ROLES, default: :planner, validate: true

  validates :name, presence: true
  validates :email, presence: true, uniqueness: true
  validates :password, length: { minimum: 8 }, allow_nil: true
  validates :role, presence: true
  validates :title, length: { maximum: 150 }, allow_blank: true
  validates :phone_number, length: { maximum: 32 }, allow_blank: true

  scope :planners, -> { where(role: ROLES[:planner]) }

  private

  def normalize_email
    self.email = email.to_s.downcase.strip
  end
end
