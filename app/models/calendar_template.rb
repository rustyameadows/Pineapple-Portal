class CalendarTemplate < ApplicationRecord
  has_many :calendar_template_items, dependent: :destroy
  has_many :calendar_template_tags, dependent: :destroy
  has_many :calendar_template_views, dependent: :destroy

  validates :name, presence: true
  validates :slug, presence: true, uniqueness: true
  validates :default_timezone, presence: true
  validates :version, numericality: { greater_than: 0 }
  validate :variable_definitions_must_be_hash

  before_validation :generate_slug, if: -> { slug.blank? && name.present? }

  scope :active, -> { where(archived: false) }

  def next_version
    version + 1
  end

  private

  def generate_slug
    base = name.to_s.parameterize
    return self.slug = base if base.blank?

    candidate = base
    suffix = 2
    scope = CalendarTemplate.where.not(id: id)

    while scope.exists?(slug: candidate)
      candidate = "#{base}-#{suffix}"
      suffix += 1
    end

    self.slug = candidate
  end

  def variable_definitions_must_be_hash
    return if variable_definitions.is_a?(Hash)

    errors.add(:variable_definitions, "must be a hash of variable definitions")
  end
end
