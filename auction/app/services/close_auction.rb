# Decides the result of an auction at stop_at (spec: requirement/biddingFlow.md §5).
#
#   CloseAuction.call(auction) # => :sold | :no_winner | :unsold | :not_due | :already_closed
#
# Idempotent and safe to call early: it re-reads the auction under a row
# lock, so an anti-sniping extension made after the job was scheduled is
# respected (the job is a no-op, and the job scheduled for the new stop_at
# does the work).
class CloseAuction
  def self.call(auction, now: Time.current)
    Auction.transaction do
      auction.lock!
      next :already_closed unless auction.open?
      next :not_due if now < auction.stop_at

      decide(auction, now)
    end
  end

  def self.decide(auction, now)
    top = auction.bids.ranked.first
    if top.nil?
      finish(auction, :unsold, now)
    elsif auction.reserve_price && top.amount < auction.reserve_price
      finish(auction, :no_winner, now)
    else
      auction.award!(winner: top.user, price: top.amount, now: now)
      :sold
    end
  end
  private_class_method :decide

  def self.finish(auction, status, now)
    auction.update!(status: status, closed_at: now)
    auction.product.update!(status: "available")
    status
  end
  private_class_method :finish
end
