class Auction < ApplicationRecord
  # Anti-sniping (spec §2.7, open point 3): a bid inside the window pushes
  # stop_at back by EXTENSION, at most MAX_EXTENSIONS times.
  ANTI_SNIPING_WINDOW = 2.minutes
  ANTI_SNIPING_EXTENSION = 2.minutes
  MAX_EXTENSIONS = 10

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

  # Call with the row locked. Returns true when stop_at was pushed back.
  def extend_for_late_bid!(now)
    return false if extension_count >= MAX_EXTENSIONS
    return false if stop_at - now > ANTI_SNIPING_WINDOW

    update!(stop_at: stop_at + ANTI_SNIPING_EXTENSION, extension_count: extension_count + 1)
    true
  end
end
