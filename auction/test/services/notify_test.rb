require "test_helper"

class NotifyOnBidTest < ActiveSupport::TestCase
  setup { @auction = auctions(:english) }

  def place(user, amount)
    PlaceBid.call(user: user, auction: @auction, amount: amount, idempotency_key: SecureRandom.uuid)
  end

  test "the previous top bidder is told they were outbid" do
    place(users(:buyer), 1_100)
    place(users(:other_buyer), 1_200)
    notes = Notification.where(kind: "outbid")
    assert_equal [ users(:buyer) ], notes.map(&:user)
    assert_equal @auction, notes.first.auction
  end

  test "the first bid notifies nobody" do
    place(users(:buyer), 1_100)
    assert_equal 0, Notification.count
  end

  test "a rejected bid notifies nobody" do
    place(users(:buyer), 1_100)
    place(users(:other_buyer), 1_100)
    assert_equal 0, Notification.count
  end
end

class NotifyOnCloseTest < ActiveSupport::TestCase
  setup do
    @auction = auctions(:english)
    @auction.update!(stop_at: 1.minute.ago, reserve_price: 2_000)
  end

  def bid(user, amount)
    @auction.bids.create!(user: user, amount: amount, idempotency_key: SecureRandom.uuid)
  end

  def kinds_by_user
    Notification.where(auction: @auction).to_h { |n| [ n.user.email, n.kind ] }
  end

  test "sold: winner won, seller sold, every other bidder lost (once each)" do
    bid(users(:buyer), 1_500)
    bid(users(:other_buyer), 1_800)
    bid(users(:buyer), 2_100)
    CloseAuction.call(@auction)
    assert_equal({ "buyer@example.com" => "won", "other@example.com" => "lost", "seller@example.com" => "seller_sold" }, kinds_by_user)
    assert_equal 3, Notification.where(auction: @auction).count
  end

  test "below reserve: seller told no winner, bidders lost" do
    bid(users(:buyer), 1_500)
    CloseAuction.call(@auction)
    assert_equal({ "buyer@example.com" => "lost", "seller@example.com" => "seller_no_winner" }, kinds_by_user)
  end

  test "no bids: only the seller is told" do
    CloseAuction.call(@auction)
    assert_equal({ "seller@example.com" => "seller_unsold" }, kinds_by_user)
  end

  test "closing twice does not notify twice" do
    bid(users(:buyer), 2_500)
    CloseAuction.call(@auction)
    CloseAuction.call(@auction)
    assert_equal 2, Notification.where(auction: @auction).count
  end

  test "dutch buy now notifies the winner and the seller" do
    dutch = auctions(:dutch)
    BuyNow.call(user: users(:buyer), auction: dutch, expected_price: 10_000, idempotency_key: "d", now: dutch.start_at + 1.minute)
    assert_equal %w[seller_sold won], Notification.where(auction: dutch).pluck(:kind).sort
  end
end
