class CalendarTemplateTag < ApplicationRecord
  belongs_to :calendar_template

  has_many :calendar_template_item_tags, dependent: :destroy
  has_many :calendar_template_items, through: :calendar_template_item_tags

  validates :name, presence: true, uniqueness: { scope: :calendar_template_id, case_sensitive: false }
  validates :position, numericality: { greater_than_or_equal_to: 0 }

  before_validation :normalize_name
  before_validation :assign_default_position, on: :create

  private

  def normalize_name
    self.name = name&.strip
  end

  def assign_default_position
    return if position.present?

    self.position = (calendar_template&.calendar_template_tags&.maximum(:position) || -1) + 1
  end
end
