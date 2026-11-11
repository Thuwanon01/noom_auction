# Manual "mark as paid" until a payment provider exists (spec open point 4).
#
#   MarkPaid.call(auction, by: user) # => :paid | :already_paid | :forbidden | :not_pending | :payment_expired
class MarkPaid
  def self.call(auction, by:, now: Time.current)
    Auction.transaction do
      auction.lock!
      next :forbidden unless by && auction.product.seller_id == by.id
      next :already_paid if auction.paid_at
      next :not_pending unless auction.sold?
      next :payment_expired if now >= auction.payment_due_at

      auction.update!(paid_at: now)
      auction.product.update!(status: "sold")
      :paid
    end
  end
end
