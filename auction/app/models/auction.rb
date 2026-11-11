class Auction < ApplicationRecord
  MONEY_FIELDS = %i[start_price reserve_price bid_increment floor_price price_drop current_price].freeze

  # Catalog phase, derived from time (spec: requirement/productCatalogFlow.md).
  # Boundaries match #live?: live while start_at <= now < stop_at, so the
  # exact stop moment is already "ended". A closed record (sold, no_winner, ...)
  # is always "ended", even if M4 closed it before stop_at (e.g. Dutch buy now).
  PHASES = %w[live upcoming ended].freeze

  # SQL twin of #listed_price.
  LISTED_PRICE_SQL = "CASE WHEN auctions.auction_type = 'sealed' THEN auctions.start_price ELSE auctions.current_price END"

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

  # Auctions anyone may browse: the product passed review and the auction was not cancelled.
  scope :publicly_listed, -> {
    joins(:product).where.not(products: { status: Product::PRIVATE_STATUSES }).where.not(status: "cancelled")
  }
  scope :live_at,     ->(now = Time.current) { open.where(start_at: ..now).where("auctions.stop_at > ?", now) }
  scope :upcoming_at, ->(now = Time.current) { open.where("auctions.start_at > ?", now).where("auctions.stop_at > ?", now) }
  scope :ended_at,    ->(now = Time.current) { where.not(status: "open").or(where(stop_at: ..now)) }

  class << self
    # SQL twin of #phase, for grouping and ordering.
    def phase_sql(now = Time.current)
      sanitize_sql_array([ <<~SQL.squish, { now: now } ])
        CASE WHEN auctions.status <> 'open' OR auctions.stop_at <= :now THEN 'ended'
             WHEN auctions.start_at > :now THEN 'upcoming'
             ELSE 'live' END
      SQL
    end

    # 0 live, 1 upcoming, 2 ended: the catalog's default grouping.
    def phase_rank_sql(now = Time.current)
      sanitize_sql_array([ <<~SQL.squish, { now: now } ])
        CASE WHEN auctions.status <> 'open' OR auctions.stop_at <= :now THEN 2
             WHEN auctions.start_at > :now THEN 1
             ELSE 0 END
      SQL
    end
  end

  def live?(now = Time.current)
    open? && start_at <= now && now < stop_at
  end

  def phase(now = Time.current)
    return "ended" if !open? || now >= stop_at
    return "upcoming" if now < start_at
    "live"
  end

  def upcoming?(now = Time.current) = phase(now) == "upcoming"
  def ended?(now = Time.current) = phase(now) == "ended"

  # The price shown in the catalog. Sealed bids are secret, so it stays at the start price.
  def listed_price = sealed? ? start_price : current_price

  def bid_count = bids.size

  def next_min_bid
    case auction_type
    when "english" then current_price + bid_increment
    when "dutch"   then current_price
    else start_price
    end
  end

  # Winning amount once ended, or nil for "ไม่มีผู้ชนะ" (reserve not met, no bids, or closed without a winner).
  def winning_price
    return if no_winner? || unsold? || cancelled?
    top = bids.ranked.first
    return if top.nil? || (reserve_price && top.amount < reserve_price)
    top.amount
  end
end
