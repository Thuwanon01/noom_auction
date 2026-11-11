class ProductImage < ApplicationRecord
  belongs_to :product
  has_one_attached :file

  default_scope { order(:position) }
end
