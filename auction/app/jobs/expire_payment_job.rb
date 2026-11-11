# Scheduled at payment_due_at when an auction is won.
class ExpirePaymentJob < ApplicationJob
  queue_as :default

  def perform(auction_id)
    auction = Auction.find_by(id: auction_id)
    ExpirePayment.call(auction) if auction
  end
end
