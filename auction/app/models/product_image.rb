class ProductImage < ApplicationRecord
  include SniffedUpload

  ALLOWED_TYPES = %w[image/jpeg image/png].freeze
  MAX_BYTES = 5.megabytes

  belongs_to :product
  has_one_attached :file do |attachable|
    attachable.variant :thumb, resize_to_fill: [ 200, 150 ]
    attachable.variant :card,  resize_to_fill: [ 640, 480 ]
  end

  default_scope { order(:position) }

  validate :file_is_acceptable
  validate :product_has_room, on: :create

  private

  def file_is_acceptable
    return errors.add(:file, "is required") unless file.attached?

    errors.add(:file, "must be a JPG or PNG image") unless ALLOWED_TYPES.include?(sniffed_content_type)
    errors.add(:file, "must be 5 MB or smaller") if file.blob.byte_size > MAX_BYTES
  end

  def product_has_room
    return unless product && product.product_images.where.not(id: id).count >= ProductWizard::MAX_IMAGES

    errors.add(:base, "A product can have at most #{ProductWizard::MAX_IMAGES} photos")
  end
end
