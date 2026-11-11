class Auction < ApplicationRecord
  MONEY_FIELDS = %i[start_price reserve_price bid_increment floor_price price_drop current_price].freeze

  enum :auction_type, %w[english dutch sealed].index_by(&:itself)
  enum :status, %w[open sold no_winner unsold cancelled].index_by(&:itself), default: "open"

  belongs_to :product
  belongs_to :winner, class_name: "User", optional: true
  has_one :seller, through: :product
  has_many :bids, dependent: :destroy

  validates :start_at, :stop_at, :start_price, :current_price, presence: true
  validates(*MONEY_FIELDS, numericality: { only_integer: true, greater_than_or_equal_to: 0 }, allow_nil: true)
  validates :extension_count, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  before_validation { self.current_price ||= start_price }

  def live?(now = Time.current)
    open? && start_at <= now && now < stop_at
  end
end
