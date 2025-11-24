class User < ApplicationRecord
  ROLES = {
    planner: "planner",
    client: "client",
    admin: "admin"
  }.freeze

  ACCOUNT_KINDS = {
    account: "account",
    contact: "contact"
  }.freeze

  before_validation :normalize_email

  has_secure_password validations: false

  has_many :event_team_members, dependent: :destroy
  has_many :events_as_team_member, through: :event_team_members, source: :event
  has_many :calendar_item_team_members, dependent: :destroy
  has_many :calendar_items_as_team_member, through: :calendar_item_team_members, source: :calendar_item
  has_many :password_reset_tokens, dependent: :delete_all

  belongs_to :avatar_global_asset,
             class_name: "GlobalAsset",
             optional: true

  attribute :account_kind, :string
  attribute :role, :string
  enum :role, ROLES, default: :planner, validate: true
  enum :account_kind, ACCOUNT_KINDS, default: :account, validate: true

  validates :name, presence: true
  validates :email, presence: true, unless: :contact?
  validates :email, uniqueness: { allow_blank: true }
  validates :password, length: { minimum: 8 }, allow_nil: true
  validates :role, presence: true
  validates :title, length: { maximum: 150 }, allow_blank: true
  validates :phone_number, length: { maximum: 32 }, allow_blank: true
  validate :avatar_must_be_image
  validate :password_required_for_account
  validate :password_confirmation_matches

  scope :planners, -> { where(role: ROLES[:planner]) }
  scope :clients, -> { where(role: ROLES[:client]) }

  def planner_or_admin?
    planner? || admin?
  end

  def latest_active_password_reset_token
    password_reset_tokens.active.most_recent_first.first
  end

  private

  def normalize_email
    self.email = email.to_s.downcase.strip
  end

  def avatar_must_be_image
    return if avatar_global_asset_id.blank?

    unless avatar_global_asset&.content_type.to_s.start_with?("image/")
      errors.add(:avatar_global_asset, "must be an image")
    end
  end

  def password_required_for_account
    return unless account?
    return if password_digest.present? || password.present?

    errors.add(:password, "can't be blank")
  end

  def password_confirmation_matches
    return if password.blank?
    return if password == password_confirmation

    errors.add(:password_confirmation, "doesn't match Password")
  end
end
