class EventTeamMember < ApplicationRecord
  belongs_to :event
  belongs_to :user

  attr_accessor :client_user_attributes

  TEAM_ROLES = {
    planner: "planner",
    client: "client"
  }.freeze

  before_validation :assign_position, on: :create
  before_validation :assign_role_from_user

  validates :user_id, uniqueness: { scope: :event_id }
  validates :position, numericality: { greater_than_or_equal_to: 0, allow_nil: false }
  validate :user_matches_member_role
  validate :lead_only_for_planners

  scope :client_visible, -> { where(client_visible: true) }
  scope :ordered_for_display, lambda {
    order(Arel.sql("CASE WHEN member_role = 'planner' THEN 0 ELSE 1 END"))
      .order(lead_planner: :desc)
      .order(:position)
      .order(:created_at)
  }

  enum :member_role, TEAM_ROLES, default: :planner

  def lead_planner?
    ActiveModel::Type::Boolean.new.cast(super)
  end

  def planner?
    member_role == TEAM_ROLES[:planner]
  end

  def client?
    member_role == TEAM_ROLES[:client]
  end

  private

  def assign_position
    self.member_role ||= TEAM_ROLES[:planner]
    return unless event
    return unless new_record? || position.nil?

    next_position = EventTeamMember.where(event_id: event_id).where.not(id: id).maximum(:position)
    self.position = next_position.present? ? next_position + 1 : 0
  end

  def assign_role_from_user
    return if member_role.present? || user.nil?

    self.member_role = if user.client?
                         TEAM_ROLES[:client]
                       else
                         TEAM_ROLES[:planner]
                       end
  end

  def user_matches_member_role
    case member_role
    when TEAM_ROLES[:planner]
      return if user&.planner? || user&.admin?
      errors.add(:user, "must be a planner or admin for planner team members")
    when TEAM_ROLES[:client]
      return if user&.client?
      errors.add(:user, "must be a client for client team members")
    else
      errors.add(:member_role, "is invalid")
    end
  end

  def lead_only_for_planners
    return if planner? || lead_planner.blank? || lead_planner == false

    errors.add(:lead_planner, "is only available for planner team members")
  end
end
