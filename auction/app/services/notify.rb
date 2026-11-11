# Creates in-app notifications for bidding events (spec §2.6, §5).
module Notify
  module_function

  def outbid(auction, user)
    Notification.create!(user: user, auction: auction, kind: :outbid)
  end

  # Call once, when the auction moves out of "open".
  def auction_closed(auction)
    seller_kind = { "sold" => :seller_sold, "no_winner" => :seller_no_winner, "unsold" => :seller_unsold }.fetch(auction.status)
    Notification.create!(user: auction.product.seller, auction: auction, kind: seller_kind)
    Notification.create!(user: auction.winner, auction: auction, kind: :won) if auction.winner

    losers = User.where(id: auction.bids.select(:user_id)).where.not(id: auction.winner_id)
    losers.find_each { |user| Notification.create!(user: user, auction: auction, kind: :lost) }
  end
end
