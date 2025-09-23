class EventCalendarTag < ApplicationRecord
  belongs_to :event_calendar

  has_many :calendar_item_tags, dependent: :destroy
  has_many :calendar_items, through: :calendar_item_tags

  validates :name, presence: true, uniqueness: { scope: :event_calendar_id, case_sensitive: false }
  validates :position, numericality: { greater_than_or_equal_to: 0 }

  before_validation :normalize_name
  before_validation :default_position, on: :create

  private

  def normalize_name
    self.name = name&.strip
  end

  def default_position
    return if position.present?

    self.position = (event_calendar&.event_calendar_tags&.maximum(:position) || -1) + 1
  end
end
