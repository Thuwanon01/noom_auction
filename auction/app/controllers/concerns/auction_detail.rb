# Loads everything auctions/show needs, so other controllers (bids) can
# re-render the detail page with an error and a fresh price box.
module AuctionDetail
  extend ActiveSupport::Concern

  private

  def load_auction_detail(id)
    @auction = Auction.publicly_listed.includes(product: :seller).find(id)
    @now = Time.current
    @action_state = AuctionActionState.for(viewer: current_user, auction: @auction, now: @now)
    @bids = helpers.bid_history_visible?(@auction, current_user, now: @now) ? @auction.bids.includes(:user).order(placed_at: :desc, id: :desc).to_a : []
  end
end
