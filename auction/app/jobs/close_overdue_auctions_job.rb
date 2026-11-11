# Safety net (config/recurring.yml): closes open auctions whose stop_at has
# passed, in case a scheduled CloseAuctionJob was lost.
class CloseOverdueAuctionsJob < ApplicationJob
  queue_as :default

  def perform
    Auction.overdue.find_each { |auction| CloseAuction.call(auction) }
  end
end
