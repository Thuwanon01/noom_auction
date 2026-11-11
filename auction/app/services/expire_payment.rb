# Cancels a sale whose winner did not pay within the window (spec §5).
#
#   ExpirePayment.call(auction) # => :cancelled | :paid | :not_due | :not_pending
class ExpirePayment
  def self.call(auction, now: Time.current)
    unpaid_winner = nil
    result = Auction.transaction do
      auction.lock!
      next :paid if auction.paid_at
      next :not_pending unless auction.sold?
      next :not_due if now < auction.payment_due_at

      unpaid_winner = auction.winner
      auction.update!(status: :cancelled, winner: nil)
      auction.product.update!(status: "available")
      :cancelled
    end
    after_cancel(auction, unpaid_winner) if result == :cancelled
    result
  end

  # Extension point. Open point 2: offer the item to the next-highest bidder
  # or relist it. Today the product simply returns to "available".
  def self.after_cancel(auction, unpaid_winner); end
end
