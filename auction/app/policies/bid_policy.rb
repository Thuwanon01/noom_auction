# Server-side eligibility for placing a bid (spec: requirement/biddingFlow.md §1).
# The UI may call this for hints, but every bid service must call it too.
#
#   result = BidPolicy.new(user:, auction:, amount:).check
#   result.allowed? / result.reason / result.message / result.limit
class BidPolicy
  # Highest single bid by credit grade. nil = no limit.
  # Open point: also applied to Dutch "Buy now" until confirmed otherwise.
  BID_LIMITS = { "A" => nil, "B" => 200_000, "C" => 50_000, "D" => 10_000 }.freeze
  FALLBACK_GRADE = "D"

  MESSAGES = {
    not_logged_in: "Log in to bid",
    onboarding_incomplete: "Complete your profile to bid",
    own_item: "You cannot bid on your own item",
    not_live: "This auction is not open for bidding",
    over_limit: "Over your bid limit. Your limit is ฿%{limit}"
  }.freeze

  Result = Data.define(:reason, :limit) do
    def allowed? = reason.nil?

    def message
      return if allowed?
      format(MESSAGES.fetch(reason), limit: limit&.to_fs(:delimited))
    end
  end

  def self.bid_limit_for(user)
    BID_LIMITS.fetch(user.credit_grade.presence || FALLBACK_GRADE) { BID_LIMITS[FALLBACK_GRADE] }
  end

  def initialize(user:, auction:, amount: nil, now: Time.current)
    @user, @auction, @amount, @now = user, auction, amount, now
  end

  def check
    return deny(:not_logged_in) if @user.nil?
    return deny(:onboarding_incomplete) unless @user.completed?
    return deny(:own_item) if @auction.product.seller_id == @user.id
    return deny(:not_live) unless @auction.live?(@now)

    limit = self.class.bid_limit_for(@user)
    return deny(:over_limit, limit) if @amount && limit && @amount > limit

    Result.new(reason: nil, limit: limit)
  end

  private

  def deny(reason, limit = nil) = Result.new(reason: reason, limit: limit)
end
