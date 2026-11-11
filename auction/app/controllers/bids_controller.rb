# Places a bid from the auction detail page (M4.4 English).
# Success redirects back with a flash; a rejected bid re-renders the detail
# page (422) with the spec message, the latest price and a new idempotency key.
class BidsController < ApplicationController
  include AuctionDetail


  def create
    return redirect_to(login_path, alert: "Log in to bid") unless current_user

    auction = Auction.publicly_listed.find(params[:auction_id])
    result = place(auction)

    if result.success?
      redirect_to auction_path(auction), notice: success_message(auction, result), status: :see_other
    else
      load_auction_detail(auction.id)
      @bid_error = result.message
      @bid_amount = params[:amount]
      @reconfirm = result.error == :price_changed
      render "auctions/show", status: :unprocessable_entity
    end
  rescue ActiveRecord::RecordNotFound
    render "auctions/not_found", status: :not_found
  end

  private

  def place(auction)
    key = params[:idempotency_key].presence || SecureRandom.uuid
    case auction.auction_type
    when "dutch"
      BuyNow.call(user: current_user, auction: auction, expected_price: params[:expected_price], idempotency_key: key)
    when "sealed"
      SubmitSealedBid.call(user: current_user, auction: auction, amount: params[:amount], idempotency_key: key)
    else
      PlaceBid.call(user: current_user, auction: auction, amount: params[:amount], idempotency_key: key,
                    expected_price: params[:expected_price].presence)
    end
  end

  def success_message(auction, result)
    price = "฿#{result.bid.amount.to_fs(:delimited)}"
    case auction.auction_type
    when "dutch" then "You bought this item for #{price}. Please pay within 48 hours"
    when "sealed" then result.revised? ? "Your sealed bid was changed to #{price}" : "Your sealed bid of #{price} was submitted"
    else "You are the highest bidder"
    end
  end
end
