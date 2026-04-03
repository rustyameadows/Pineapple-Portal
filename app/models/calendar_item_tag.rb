class CalendarItemTag < ApplicationRecord
  belongs_to :calendar_item
  belongs_to :event_calendar_tag

  validates :calendar_item_id, uniqueness: { scope: :event_calendar_tag_id }
  validate :tag_belongs_to_same_calendar

  after_commit :refresh_item_tag_summary, on: %i[create destroy]
  after_commit :enqueue_generated_packet_refresh, on: %i[create update destroy]

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

  def enqueue_generated_packet_refresh
    event_id = calendar_item&.event_calendar&.event_id
    return unless event_id.present?

    Documents::Generated::RefreshEventPacketCachesJob.perform_later(event_id)
  end
end
