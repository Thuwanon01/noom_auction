# Scheduled at stop_at by Auction (and again whenever stop_at moves).
class CloseAuctionJob < ApplicationJob
  queue_as :default

  def perform(auction_id)
    auction = Auction.find_by(id: auction_id)
    CloseAuction.call(auction) if auction
  end
end
