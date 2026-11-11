class Auction < ApplicationRecord
  # Anti-sniping (spec §2.7, open point 3): a bid inside the window pushes
  # stop_at back by EXTENSION, at most MAX_EXTENSIONS times.
  ANTI_SNIPING_WINDOW = 2.minutes
  ANTI_SNIPING_EXTENSION = 2.minutes
  MAX_EXTENSIONS = 10

  PAYMENT_WINDOW = 48.hours

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
  after_commit :schedule_close, if: -> { open? && saved_change_to_stop_at? }
  # M4.9: price, extension, Sold and close all re-render open detail pages.
  # The broadcast is a data-free "refresh"; each browser re-fetches the page
  # as its own user, so per-viewer and sealed content is never broadcast.
  after_update_commit :broadcast_refresh_later

  scope :overdue, ->(now = Time.current) { open.where(stop_at: ..now) }
  scope :payment_overdue, ->(now = Time.current) { sold.where(paid_at: nil, payment_due_at: ..now) }

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
  # hidden until the auction ends: a bidder sees only their own bid, others
  # see none. "Ends" is stop_at (or an earlier close), not the close job,
  # because no bid can be placed after stop_at anyway.
  def bids_visible_to(viewer, now = Time.current)
    scope = bids.order(placed_at: :desc, id: :desc)
    return scope unless sealed? && !ended?(now)

    viewer ? scope.where(user: viewer) : scope.none
  end

  # Close with a winner. Call with the row locked. The winner has
  # PAYMENT_WINDOW to pay before ExpirePaymentJob cancels the sale.
  def award!(winner:, price:, now:)
    update!(status: :sold, winner: winner, current_price: price, closed_at: now, payment_due_at: now + PAYMENT_WINDOW)
    product.update!(status: "sold") # M2 lifecycle: in_event -> sold; sold -> available if unpaid
    Notify.auction_closed(self)
    ExpirePaymentJob.set(wait_until: payment_due_at).perform_later(id)
  end

  # Call with the row locked. Returns true when stop_at was pushed back.
  def extend_for_late_bid!(now)
    return false if extension_count >= MAX_EXTENSIONS
    return false if stop_at - now > ANTI_SNIPING_WINDOW

    update!(stop_at: stop_at + ANTI_SNIPING_EXTENSION, extension_count: extension_count + 1)
    true
  end

  def phase(now = Time.current)
    return "ended" if !open? || now >= stop_at
    return "upcoming" if now < start_at
    "live"
  end

  def upcoming?(now = Time.current) = phase(now) == "upcoming"
  def ended?(now = Time.current) = phase(now) == "ended"

  # The price shown in the catalog. Sealed bids are secret, so it stays at the
  # start price. An open Dutch auction shows the price at that moment.
  # (LISTED_PRICE_SQL still sorts Dutch by the stored current_price.)
  def listed_price(now = Time.current)
    return start_price if sealed?
    return dutch_price_at(now) if dutch? && open?
    current_price
  end

  def bid_count = bids.size

  def next_min_bid(now = Time.current)
    case auction_type
    when "english" then current_price + bid_increment
    when "dutch"   then listed_price(now)
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

  private

  def schedule_close
    CloseAuctionJob.set(wait_until: stop_at).perform_later(id)
  end

  def dutch_interval = drop_interval_minutes.to_i.minutes

  def dutch_drops_at(time)
    return 0 if time <= start_at || dutch_interval.zero?

    ((time - start_at) / dutch_interval).floor
  end
end
