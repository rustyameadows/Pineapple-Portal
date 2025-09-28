class GlobalAsset < ApplicationRecord
  belongs_to :uploaded_by, class_name: "User", optional: true

  validates :storage_uri, :filename, :content_type, presence: true
  validates :size_bytes, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true

  scope :images, -> { where("content_type LIKE ?", "image/%") }
end
