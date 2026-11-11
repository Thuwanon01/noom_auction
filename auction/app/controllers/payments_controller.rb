# Manual "mark as paid" by the seller (M4.11) until a payment provider exists.
class PaymentsController < ApplicationController
  MESSAGES = {
    paid: [ :notice, "Marked as paid" ],
    already_paid: [ :notice, "Already marked as paid" ],
    forbidden: [ :alert, "Only the seller can mark this as paid" ],
    not_pending: [ :alert, "This auction is not waiting for payment" ],
    payment_expired: [ :alert, "The payment window has ended" ]
  }.freeze

  def create
    return redirect_to(login_path, alert: "Log in first") unless current_user

    auction = Auction.find(params[:auction_id])
    kind, message = MESSAGES.fetch(MarkPaid.call(auction, by: current_user))
    redirect_to auction_path(auction), kind => message, status: :see_other
  end
end
