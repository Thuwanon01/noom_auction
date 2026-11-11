# M2.1 (#18). Transitions between statuses are M2.2 (#19); step validations are M2.3-M2.5.
class Product < ApplicationRecord
  CATEGORIES = %w[camera watch musical_instrument it sports collectible furniture art vehicle other].freeze
  # Categories where the seller must upload proof of authenticity (M2.4).
  PROOF_REQUIRED_CATEGORIES = %w[collectible vehicle].freeze

  enum :category, CATEGORIES.index_by(&:itself)
  enum :condition, %w[new like_new good fair for_parts].index_by(&:itself), prefix: true
  # pending_payment: auction closed with a winner, waiting for the 48-hour payment (M4.10/M4.11).
  enum :status, %w[draft pending_review rejected available in_event pending_payment sold withdrawn].index_by(&:itself), default: "draft"

  belongs_to :seller, class_name: "User"
  has_one :auction, dependent: :destroy
  has_many :product_images, dependent: :destroy
  has_many :product_documents, dependent: :destroy

  validates :code, presence: true, uniqueness: true
  validates :name, presence: true

  def proof_required?
    PROOF_REQUIRED_CATEGORIES.include?(category)
  end
end
