# Which action area the auction detail page shows (M3.9 #35).
#
#   | Viewer          | live              | upcoming            | ended  |
#   | Guest           | :login_to_bid     | :login              | :result|
#   | Not onboarded   | :complete_profile | :complete_profile   | :result|
#   | Eligible buyer  | :bid_form         | :remind_me          | :result|
#   | Top bidder (EN) | :highest_bidder   |                     | :result|
#   | Seller of item  | :own_item         | :edit_until_start   | :result|
#
# Live states reuse BidPolicy (M4.2) so the page hint and the server rule agree.
# Being over the bid limit still shows the bid form; the form explains the limit.
class AuctionActionState
  STATES = %i[login_to_bid login complete_profile bid_form highest_bidder remind_me own_item edit_until_start result].freeze

  def self.for(viewer:, auction:, now: Time.current) = new(viewer:, auction:, now:).state

  def initialize(viewer:, auction:, now: Time.current)
    @viewer, @auction, @now = viewer, auction, now
  end

  def state
    case @auction.phase(@now)
    when "ended"    then :result
    when "live"     then live_state
    when "upcoming" then upcoming_state
    end
  end

  private

  def live_state
    case BidPolicy.new(user: @viewer, auction: @auction, now: @now).check.reason
    when :not_logged_in         then :login_to_bid
    when :onboarding_incomplete then :complete_profile
    when :own_item              then :own_item
    else highest_bidder? ? :highest_bidder : :bid_form
    end
  end

  # English: the top bidder cannot bid again until outbid (spec §2.8).
  def highest_bidder?
    @auction.english? && @auction.bids.ranked.first&.user_id == @viewer.id
  end

  def upcoming_state
    return :login if @viewer.nil?
    return :edit_until_start if seller?
    return :complete_profile unless @viewer.completed?
    :remind_me
  end

  def seller? = @auction.product.seller_id == @viewer.id
end
