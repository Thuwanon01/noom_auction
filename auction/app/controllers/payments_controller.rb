# Manual "mark as paid" by the seller (M4.11) until a payment provider exists.
class PaymentsController < ApplicationController
  MESSAGES = {
    paid: [ :bid_notice, "Marked as paid" ],
    already_paid: [ :bid_notice, "Already marked as paid" ],
    forbidden: [ :bid_alert, "Only the seller can mark this as paid" ],
    not_pending: [ :bid_alert, "This auction is not waiting for payment" ],
    payment_expired: [ :bid_alert, "The payment window has ended" ]
  }.freeze

  def create
    return redirect_to(login_path, alert: "Log in first") unless current_user

    auction = Auction.find(params[:auction_id])
    kind, message = MESSAGES.fetch(MarkPaid.call(auction, by: current_user))
    redirect_to auction_path(auction), flash: { kind => message }, status: :see_other
  end
end
