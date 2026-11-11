# "Buy now" on a Dutch auction (spec: requirement/biddingFlow.md §3).
#
#   result = BuyNow.call(user:, auction:, expected_price:, idempotency_key:)
#
# The price is always the server's price at request time. expected_price is
# only used to detect that the price dropped after the dialog opened; then
# the caller must show result.price and ask again. The first accepted
# purchase wins and closes the auction in the same locked transaction.
class BuyNow
  MESSAGES = {
    price_changed: "Price changed. The new price is ฿%{price}",
    sold: "Sold",
    auction_ended: "This auction has just ended",
    wrong_auction_type: "This auction does not accept bids"
  }.freeze

  Result = Data.define(:bid, :error, :message, :price, :replayed) do
    def success? = error.nil?
    def replayed? = replayed
  end

  def self.call(...) = new(...).call

  def initialize(user:, auction:, expected_price:, idempotency_key:, now: nil)
    @user, @auction, @idempotency_key, @now = user, auction, idempotency_key, now
    @expected_price = PlaceBid.parse_amount(expected_price)
  end

  def call
    return fail(:wrong_auction_type) unless @auction.dutch?
    if (existing = find_existing)
      return ok(existing, replayed: true)
    end

    Auction.transaction do
      @auction.lock!
      if (existing = find_existing)
        next ok(existing, replayed: true)
      end

      buy_locked
    end
  rescue ActiveRecord::RecordNotUnique
    ok(find_existing, replayed: true)
  end

  private

  def buy_locked
    now = @now || Time.current
    price = @auction.dutch_price_at(now)

    policy = BidPolicy.new(user: @user, auction: @auction, amount: price, now: now).check
    unless policy.allowed?
      return fail(:sold) if policy.reason == :not_live && @auction.sold?
      return fail(:auction_ended) if policy.reason == :not_live && now >= @auction.start_at
      return Result.new(bid: nil, error: policy.reason, message: policy.message, price: price, replayed: false)
    end

    return fail(:price_changed, price: price) unless @expected_price == price

    bid = @auction.bids.create!(user: @user, amount: price, placed_at: now, idempotency_key: @idempotency_key)
    @auction.award!(winner: @user, price: price, now: now)
    ok(bid)
  end

  def find_existing
    Bid.find_by(user: @user, auction: @auction, idempotency_key: @idempotency_key)
  end

  def ok(bid, replayed: false)
    Result.new(bid: bid, error: nil, message: nil, price: bid.amount, replayed: replayed)
  end

  def fail(error, price: nil)
    Result.new(bid: nil, error: error, message: format(MESSAGES.fetch(error), price: price&.to_fs(:delimited)), price: price, replayed: false)
  end
end
