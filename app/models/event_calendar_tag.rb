class EventCalendarTag < ApplicationRecord
  belongs_to :event_calendar

  has_many :calendar_item_tags, dependent: :destroy
  has_many :calendar_items, through: :calendar_item_tags

  validates :name, presence: true, uniqueness: { scope: :event_calendar_id, case_sensitive: false }
  validates :position, numericality: { greater_than_or_equal_to: 0 }

  before_validation :normalize_name
  before_validation :default_position, on: :create
  after_commit :refresh_calendar_item_tag_summaries, on: :update, if: :saved_change_to_name?
  after_commit :enqueue_generated_packet_refresh, on: %i[create update destroy], if: :generated_packet_refresh_needed?

  private

  def normalize_name
    self.name = name&.strip
  end

  def default_position
    return if position.present?

    self.position = (event_calendar&.event_calendar_tags&.maximum(:position) || -1) + 1
  end

  def refresh_calendar_item_tag_summaries
    calendar_items.find_each(&:refresh_tag_summary!)
  end

  def generated_packet_refresh_needed?
    event_calendar&.master?
  end

  def enqueue_generated_packet_refresh
    event_id = event_calendar&.event_id
    return unless event_id.present?

    Documents::Generated::RefreshEventPacketCachesJob.perform_later(event_id)
  end
end
