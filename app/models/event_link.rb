class EventLink < ApplicationRecord
  LINK_TYPES = %w[quick planning internal financial].freeze

  belongs_to :event

  before_validation :assign_position, on: :create

  validates :label, presence: true
  validates :url, presence: true
  validates :position, presence: true
  validates :link_type, inclusion: { in: LINK_TYPES }

  attribute :link_type, :string, default: "quick"

  scope :ordered, -> { order(:position, :id) }
  scope :with_type, ->(type) { where(link_type: type) }
  scope :quick, -> { with_type("quick") }
  scope :planning, -> { with_type("planning") }
  scope :internal, -> { with_type("internal") }
  scope :financial, -> { with_type("financial") }

  private

  def assign_position
    return if position.present? || event.nil?

    type_scope = event.event_links.where(link_type: link_type.presence || "quick")
    self.position = type_scope.maximum(:position).to_i + 1
  end
end
