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

  # Dutch: start price minus one drop per full interval since start_at,
  # never below the floor (spec §3.1).
  def dutch_price_at(time)
    [ start_price - dutch_drops_at(time) * price_drop.to_i, floor_price.to_i ].max
  end

  # When the Dutch price next drops, or nil once it has reached the floor.
  def next_dutch_drop_at(time)
    return if dutch_price_at(time) <= floor_price.to_i

    start_at + (dutch_drops_at(time) + 1) * dutch_interval
  end

  # Bid history the viewer may see (spec §4.5, §6). Sealed amounts stay
  # hidden until close: a bidder sees only their own bid, others see none.
  def bids_visible_to(viewer)
    scope = bids.order(placed_at: :desc, id: :desc)
    return scope unless sealed? && open?

    viewer ? scope.where(user: viewer) : scope.none
  end

  # Close with a winner. Call with the row locked.
  def award!(winner:, price:, now:)
    update!(status: :sold, winner: winner, current_price: price, closed_at: now)
    product.update!(status: "pending_payment")
  end

  # Call with the row locked. Returns true when stop_at was pushed back.
  def extend_for_late_bid!(now)
    return false if extension_count >= MAX_EXTENSIONS
    return false if stop_at - now > ANTI_SNIPING_WINDOW

    update!(stop_at: stop_at + ANTI_SNIPING_EXTENSION, extension_count: extension_count + 1)
    true
  end

  private

  def dutch_interval = drop_interval_minutes.to_i.minutes

  def dutch_drops_at(time)
    return 0 if time <= start_at || dutch_interval.zero?

    ((time - start_at) / dutch_interval).floor
  end
end
