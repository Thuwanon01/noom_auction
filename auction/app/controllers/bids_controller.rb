# Places a bid from the auction detail page (M4.4 English).
# Success redirects back with a flash; a rejected bid re-renders the detail
# page (422) with the spec message, the latest price and a new idempotency key.
class BidsController < ApplicationController
  include AuctionDetail

  before_action :require_login

  SUCCESS_MESSAGES = { "english" => "You are the highest bidder" }.freeze

  def create
    auction = Auction.publicly_listed.find(params[:auction_id])
    result = place(auction)

    if result.success?
      redirect_to auction_path(auction), flash: { bid_notice: SUCCESS_MESSAGES.fetch(auction.auction_type) }, status: :see_other
    else
      load_auction_detail(auction.id)
      @bid_error = result.message
      @bid_amount = params[:amount]
      render "auctions/show", status: :unprocessable_entity
    end
  rescue ActiveRecord::RecordNotFound
    render "auctions/not_found", status: :not_found
  end

  private

  def place(auction)
    PlaceBid.call(user: current_user, auction: auction, amount: params[:amount],
                  idempotency_key: params[:idempotency_key].presence || SecureRandom.uuid,
                  expected_price: params[:expected_price].presence)
  end
end
