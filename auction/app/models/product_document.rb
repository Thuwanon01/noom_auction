class ProductDocument < ApplicationRecord
  include SniffedUpload

  ALLOWED_TYPES = %w[application/pdf image/jpeg image/png].freeze
  MAX_BYTES = 10.megabytes # the spec gives no limit for proof files; scans are bigger than photos

  belongs_to :product
  has_one_attached :file

  enum :kind, %w[proof].index_by(&:itself), default: "proof"

  validate :file_is_acceptable

  private

  def file_is_acceptable
    return errors.add(:file, "is required") unless file.attached?

    errors.add(:file, "must be a PDF, JPG or PNG") unless ALLOWED_TYPES.include?(sniffed_content_type)
    errors.add(:file, "must be 10 MB or smaller") if file.blob.byte_size > MAX_BYTES
  end
end
