# Rows for the "My bids" page (M4.13, spec §6). One row per auction the user
# has bid on, with a derived status:
#
#   | Auction state                       | Status     |
#   | English, open, user is the top bid  | :winning   |
#   | English, open, someone bid higher   | :outbid    |
#   | Sealed, open                        | :submitted | ranking is secret until close
#   | Closed (sold) with user as winner   | :won       | any type, incl. Dutch buy now
#   | Any other closed or ended state     | :lost      | lost, below reserve, unpaid/cancelled
#
# "Open" means status open; an auction past stop_at that the close job has
# not processed yet keeps its open status until it is closed.
class MyBids
  STATUS_LABELS = { winning: "Winning", outbid: "Outbid", submitted: "Submitted", won: "Won", lost: "Lost" }.freeze

  Row = Data.define(:auction, :my_amount, :status) do
    def label = STATUS_LABELS.fetch(status)
    def payment_due_at = (auction.payment_due_at if status == :won)
    def paid? = status == :won && auction.paid_at.present?
  end

  def self.for(user)
    auctions = Auction.where(id: user.bids.select(:auction_id)).includes(:bids, product: :seller)
    rows = auctions.map { |auction| build_row(auction, user) }
    rows.sort_by { |r| r.auction.open? ? [ 0, r.auction.stop_at.to_i ] : [ 1, -r.auction.closed_at.to_i ] }
  end

  def self.build_row(auction, user)
    mine = auction.bids.select { |b| b.user_id == user.id }
    Row.new(auction: auction, my_amount: mine.map(&:amount).max, status: status_for(auction, user))
  end

  def self.status_for(auction, user)
    return auction.winner_id == user.id ? :won : :lost unless auction.open?
    return :submitted if auction.sealed?

    top = auction.bids.min_by { |b| [ -b.amount, b.placed_at ] }
    top&.user_id == user.id ? :winning : :outbid
  end
  private_class_method :build_row, :status_for
end
