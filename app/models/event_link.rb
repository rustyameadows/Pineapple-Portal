class EventLink < ApplicationRecord
  belongs_to :event

  before_validation :assign_position, on: :create

  validates :label, presence: true
  validates :url, presence: true
  validates :position, presence: true

  scope :ordered, -> { order(:position, :id) }

  private

  def assign_position
    return if position.present? || event.nil?

    self.position = event.event_links.maximum(:position).to_i + 1
  end
end
