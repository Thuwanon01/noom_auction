# Submits or revises a sealed bid (spec: requirement/biddingFlow.md §4).
#
#   result = SubmitSealedBid.call(user:, auction:, amount:, idempotency_key:)
#
# One bid per user per auction. A revise before stop_at replaces the amount
# and RESETS placed_at, so the tie-break (earliest bid wins) rewards the time
# the winning amount was committed, not the time of an earlier lower bid.
# The result only ever holds the caller's own bid and the bid count.
class SubmitSealedBid
  MESSAGES = {
    invalid_amount: "Enter a valid amount",
    below_minimum: "The minimum bid is ฿%{minimum}",
    auction_ended: "This auction has just ended",
    wrong_auction_type: "This auction does not accept bids"
  }.freeze

  Result = Data.define(:bid, :error, :message, :bid_count, :revised, :replayed) do
    def success? = error.nil?
    def revised? = revised
    def replayed? = replayed
  end

  def self.call(...) = new(...).call

  def initialize(user:, auction:, amount:, idempotency_key:, now: nil)
    @user, @auction, @idempotency_key, @now = user, auction, idempotency_key, now
    @amount = PlaceBid.parse_amount(amount)
  end

  def call
    return fail(:wrong_auction_type) unless @auction.sealed?
    return fail(:invalid_amount) unless @amount

    Auction.transaction do
      @auction.lock!
      own = @auction.bids.find_by(user: @user)
      next ok(own, replayed: true) if own && own.idempotency_key == @idempotency_key

      submit_locked(own)
    end
  end

  private

  def submit_locked(own)
    now = @now || Time.current
    policy = BidPolicy.new(user: @user, auction: @auction, amount: @amount, now: now).check
    unless policy.allowed?
      return fail(:auction_ended) if policy.reason == :not_live && now >= @auction.start_at
      return Result.new(bid: nil, error: policy.reason, message: policy.message, bid_count: nil, revised: false, replayed: false)
    end
    return fail(:below_minimum, minimum: @auction.start_price) if @amount < @auction.start_price

    attrs = { amount: @amount, placed_at: now, idempotency_key: @idempotency_key }
    if own
      own.update!(attrs)
      ok(own, revised: true)
    else
      ok(@auction.bids.create!(attrs.merge(user: @user)))
    end
  end

  def ok(bid, revised: false, replayed: false)
    Result.new(bid: bid, error: nil, message: nil, bid_count: @auction.bids.count, revised: revised, replayed: replayed)
  end

  def fail(error, minimum: nil)
    message = format(MESSAGES.fetch(error), minimum: minimum&.to_fs(:delimited))
    Result.new(bid: nil, error: error, message: message, bid_count: nil, revised: false, replayed: false)
  end
end
