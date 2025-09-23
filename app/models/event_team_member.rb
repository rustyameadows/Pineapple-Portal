class EventTeamMember < ApplicationRecord
  belongs_to :event
  belongs_to :user

  validates :user_id, uniqueness: { scope: :event_id }
  validate :user_is_planner

  scope :client_visible, -> { where(client_visible: true) }

  private

  def user_is_planner
    return if user&.planner? || user&.admin?

    errors.add(:user, "must be a planner")
  end
end
