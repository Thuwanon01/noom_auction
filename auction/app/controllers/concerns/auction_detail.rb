# Loads everything auctions/show needs, so other controllers (bids) can
# re-render the detail page with an error and a fresh price box.
module AuctionDetail
  extend ActiveSupport::Concern

  private

  def load_auction_detail(id)
    @auction = Auction.publicly_listed.includes(product: :seller).find(id)
    @now = Time.current
    @action_state = AuctionActionState.for(viewer: current_user, auction: @auction, now: @now)
    # Single visibility rule (Auction#bids_visible_to): before a sealed auction
    # ends this holds at most the viewer's own bid, never anyone else's amount.
    @bids = @auction.bids_visible_to(current_user, @now).includes(:user).to_a
  end
end
