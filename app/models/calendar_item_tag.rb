class CalendarItemTag < ApplicationRecord
  belongs_to :calendar_item
  belongs_to :event_calendar_tag

  validates :calendar_item_id, uniqueness: { scope: :event_calendar_tag_id }
  validate :tag_belongs_to_same_calendar

  after_commit :refresh_item_tag_summary, on: %i[create destroy]

  private

  def tag_belongs_to_same_calendar
    return if calendar_item.blank? || event_calendar_tag.blank?

    if calendar_item.event_calendar_id != event_calendar_tag.event_calendar_id
      errors.add(:event_calendar_tag_id, "must belong to the same calendar")
    end
  end

  def refresh_item_tag_summary
    calendar_item.refresh_tag_summary!
  end
end
