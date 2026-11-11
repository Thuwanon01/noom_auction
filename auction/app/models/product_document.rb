class ProductDocument < ApplicationRecord
  belongs_to :product
  has_one_attached :file

  enum :kind, %w[proof].index_by(&:itself), default: "proof"
end
