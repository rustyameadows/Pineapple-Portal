require "set"

class CalendarTemplateItem < ApplicationRecord
  belongs_to :calendar_template
  belongs_to :relative_anchor_template_item,
             class_name: "CalendarTemplateItem",
             optional: true

  has_many :dependent_template_items,
           class_name: "CalendarTemplateItem",
           foreign_key: :relative_anchor_template_item_id,
           dependent: :nullify,
           inverse_of: :relative_anchor_template_item

  has_many :calendar_template_item_tags, dependent: :destroy
  has_many :calendar_template_tags, through: :calendar_template_item_tags

  validates :title, presence: true
  validates :duration_minutes, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validates :default_offset_minutes, presence: true
  validate :relative_anchor_same_template
  validate :prevent_circular_dependency

  before_validation :default_offset
  before_validation :default_position, on: :create

  scope :ordered, -> { order(:position, :id) }

  private

  def default_offset
    self.default_offset_minutes ||= 0
  end

  def default_position
    return if position.present?

    self.position = (calendar_template&.calendar_template_items&.maximum(:position) || -1) + 1
  end

  def relative_anchor_same_template
    return if relative_anchor_template_item.blank?

    if relative_anchor_template_item_id == id
      errors.add(:relative_anchor_template_item_id, "cannot reference itself")
    elsif relative_anchor_template_item.calendar_template_id != calendar_template_id
      errors.add(:relative_anchor_template_item_id, "must reference an item in the same template")
    end
  end

  def prevent_circular_dependency
    return if relative_anchor_template_item.blank?

    visited = Set.new
    node = relative_anchor_template_item

    while node
      if node.id == id
        errors.add(:relative_anchor_template_item_id, "creates a circular dependency")
        break
      end
      break unless node.relative_anchor_template_item

      node = node.relative_anchor_template_item
      break if visited.include?(node.id)

      visited << node.id
    end
  end
end
