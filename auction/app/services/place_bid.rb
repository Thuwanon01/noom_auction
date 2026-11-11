# Places a bid on an English auction (spec: requirement/biddingFlow.md §2).
#
#   result = PlaceBid.call(user:, auction:, amount:, idempotency_key:, expected_price: nil)
#
# The auction row is locked for the whole check-and-write, so concurrent bids
# are serialized and current_price is always the latest accepted bid.
# Pass expected_price (the current price the client showed) to get
# "Price changed" instead of "The minimum bid is" when someone bid first.
class PlaceBid
  MESSAGES = {
    invalid_amount: "Enter a valid amount",
    below_minimum: "The minimum bid is ฿%{minimum}",
    price_changed: "Price changed. The new minimum is ฿%{minimum}",
    already_highest: "You are already the highest bidder",
    auction_ended: "This auction has just ended",
    wrong_auction_type: "This auction does not accept bids"
  }.freeze

  Result = Data.define(:bid, :error, :message, :minimum, :previous_leader, :replayed) do
    def self.ok(bid, previous_leader: nil, replayed: false)
      new(bid:, error: nil, message: nil, minimum: nil, previous_leader:, replayed:)
    end

    def self.fail(error, message, minimum: nil)
      new(bid: nil, error:, message:, minimum:, previous_leader: nil, replayed: false)
    end

    def success? = error.nil?
    def replayed? = replayed
  end

  def self.call(...) = new(...).call

  def initialize(user:, auction:, amount:, idempotency_key:, expected_price: nil, now: nil)
    @user, @auction, @idempotency_key = user, auction, idempotency_key
    @amount = self.class.parse_amount(amount)
    @expected_price = expected_price&.to_i
    @now = now
  end

  # Whole baht only. Returns nil for anything else.
  def self.parse_amount(value)
    case value
    when Integer then value
    when String then Integer(value, 10, exception: false) if value.strip.match?(/\A\d+\z/)
    when Numeric then value.to_i if value == value.to_i
    end&.then { |n| n.positive? ? n : nil }
  end

  def call
    return fail(:wrong_auction_type) unless @auction.english?
    return fail(:invalid_amount) unless @amount

    if (existing = find_existing)
      return Result.ok(existing, replayed: true)
    end

    Auction.transaction do
      @auction.lock!
      if (existing = find_existing)
        next Result.ok(existing, replayed: true)
      end

      place_locked
    end
  rescue ActiveRecord::RecordNotUnique
    Result.ok(find_existing, replayed: true)
  end

  private

  def place_locked
    now = @now || Time.current
    policy = BidPolicy.new(user: @user, auction: @auction, amount: @amount, now: now).check
    unless policy.allowed?
      return fail(:auction_ended) if policy.reason == :not_live && ended?(now)
      return Result.fail(policy.reason, policy.message)
    end

    leader = @auction.bids.ranked.first&.user
    return fail(:already_highest) if leader == @user

    minimum = @auction.current_price + @auction.bid_increment
    if @amount < minimum
      changed = @expected_price && @expected_price != @auction.current_price
      return fail(changed ? :price_changed : :below_minimum, minimum: minimum)
    end

    bid = @auction.bids.create!(user: @user, amount: @amount, placed_at: now, idempotency_key: @idempotency_key)
    @auction.update!(current_price: @amount)
    Result.ok(bid, previous_leader: leader)
  end

  def ended?(now) = now >= @auction.stop_at || !@auction.open?

  def find_existing
    Bid.find_by(user: @user, auction: @auction, idempotency_key: @idempotency_key)
  end

  def fail(error, minimum: nil)
    Result.fail(error, format(MESSAGES.fetch(error), minimum: minimum&.to_fs(:delimited)), minimum: minimum)
  end
end
