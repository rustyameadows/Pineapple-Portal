class CalendarTemplateView < ApplicationRecord
  belongs_to :calendar_template

  validates :name, presence: true
  validates :slug, presence: true, uniqueness: { scope: :calendar_template_id }
  validate :tag_filter_must_match_template

  before_validation :generate_slug, if: -> { slug.blank? && name.present? }
  before_validation :normalize_tag_filter

  scope :client_visible_by_default, -> { where(client_visible_by_default: true) }

  private

  def generate_slug
    base = name.to_s.parameterize
    return self.slug = base if base.blank?

    candidate = base
    suffix = 2
    scope = CalendarTemplateView.where(calendar_template_id: calendar_template_id)
    scope = scope.where.not(id: id) if id

    while scope.exists?(slug: candidate)
      candidate = "#{base}-#{suffix}"
      suffix += 1
    end

    self.slug = candidate
  end

  def normalize_tag_filter
    self.tag_filter = Array(tag_filter)
                       .reject(&:blank?)
                       .map(&:to_i)
                       .uniq
  end

  def tag_filter_must_match_template
    return unless calendar_template

    valid_ids = calendar_template.calendar_template_tags.pluck(:id)
    invalid = tag_filter - valid_ids
    errors.add(:tag_filter, "contains unknown tags") if invalid.any?
  end
end
