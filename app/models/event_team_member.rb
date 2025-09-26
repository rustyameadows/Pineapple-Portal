class EventTeamMember < ApplicationRecord
  belongs_to :event
  belongs_to :user

  before_validation :assign_position, on: :create

  validates :user_id, uniqueness: { scope: :event_id }
  validates :position, numericality: { greater_than_or_equal_to: 0, allow_nil: false }
  validate :user_is_planner

  scope :client_visible, -> { where(client_visible: true) }
  scope :ordered_for_display, lambda {
    order(lead_planner: :desc).order(:position).order(:created_at)
  }

  def lead_planner?
    ActiveModel::Type::Boolean.new.cast(super)
  end

  private

  def assign_position
    return if position.present?
    return unless event

    next_position = event.event_team_members.maximum(:position)
    self.position = next_position.present? ? next_position + 1 : 0
  end

  def user_is_planner
    return if user&.planner? || user&.admin?

    errors.add(:user, "must be a planner")
  end
end
