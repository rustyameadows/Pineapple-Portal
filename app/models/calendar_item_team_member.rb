class CalendarItemTeamMember < ApplicationRecord
  belongs_to :calendar_item
  belongs_to :user

  validates :user_id, uniqueness: { scope: :calendar_item_id }
end
