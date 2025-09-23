class CalendarTemplateItemTag < ApplicationRecord
  belongs_to :calendar_template_item
  belongs_to :calendar_template_tag

  validates :calendar_template_item_id, uniqueness: { scope: :calendar_template_tag_id }
  validate :tag_belongs_to_same_template

  private

  def tag_belongs_to_same_template
    return unless calendar_template_item && calendar_template_tag

    if calendar_template_item.calendar_template_id != calendar_template_tag.calendar_template_id
      errors.add(:calendar_template_tag_id, "must belong to the same template")
    end
  end
end
