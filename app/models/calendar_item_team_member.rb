class CalendarItemTeamMember < ApplicationRecord
  belongs_to :calendar_item
  belongs_to :user

  validates :user_id, uniqueness: { scope: :calendar_item_id }

  after_commit :enqueue_generated_packet_refresh, on: %i[create update destroy]

  private

  def enqueue_generated_packet_refresh
    event_id = calendar_item&.event_calendar&.event_id
    return unless event_id.present?

    Documents::Generated::RefreshEventPacketCachesJob.perform_later(event_id)
  end
end
