require "test_helper"

class MyBidsTest < ActiveSupport::TestCase
  include CatalogFactory

  setup do
    @me = users(:buyer)
    @other = users(:other_buyer)
  end

  def row_for(auction) = MyBids.for(@me).find { |r| r.auction == auction }

  test "English, open, I am the top bid: Winning" do
    a = auctions(:english)
    place_bid(a, @other, 1_100, at: 2.minutes.ago)
    place_bid(a, @me, 1_200, at: 1.minute.ago)
    assert_equal :winning, row_for(a).status
    assert_equal 1_200, row_for(a).my_amount
  end

  test "English, open, someone bid higher: Outbid" do
    a = auctions(:english)
    place_bid(a, @me, 1_100, at: 2.minutes.ago)
    place_bid(a, @other, 1_200, at: 1.minute.ago)
    assert_equal :outbid, row_for(a).status
  end

  test "Sealed, open: Submitted (never reveals the ranking)" do
    a = auctions(:sealed)
    place_bid(a, @me, 1_000_000)
    place_bid(a, @other, 2_500)
    assert_equal :submitted, row_for(a).status
  end

  test "closed with me as winner: Won, with the payment deadline" do
    a = auctions(:english)
    a.update_columns(stop_at: 1.minute.ago, reserve_price: nil)
    place_bid(a, @me, 1_500, at: 2.minutes.ago)
    CloseAuction.call(a)
    row = row_for(a)
    assert_equal :won, row.status
    assert_equal a.reload.payment_due_at, row.payment_due_at
  end

  test "Dutch buy: Won" do
    a = auctions(:dutch)
    BuyNow.call(user: @me, auction: a, expected_price: a.dutch_price_at(Time.current), idempotency_key: "d")
    assert_equal :won, row_for(a).status
  end

  test "closed with someone else winning: Lost" do
    a = auctions(:english)
    a.update_columns(stop_at: 1.minute.ago, reserve_price: nil)
    place_bid(a, @me, 1_100, at: 3.minutes.ago)
    place_bid(a, @other, 1_500, at: 2.minutes.ago)
    CloseAuction.call(a)
    assert_equal :lost, row_for(a).status
  end

  test "closed below reserve: Lost" do
    a = auctions(:english)
    a.update_columns(stop_at: 1.minute.ago, reserve_price: 5_000)
    place_bid(a, @me, 1_500, at: 2.minutes.ago)
    CloseAuction.call(a)
    assert_equal :lost, row_for(a).status
  end

  test "sale cancelled for non-payment: Lost" do
    a = auctions(:english)
    a.update_columns(stop_at: 1.minute.ago, reserve_price: nil)
    place_bid(a, @me, 1_500, at: 2.minutes.ago)
    CloseAuction.call(a)
    ExpirePayment.call(a.reload, now: a.payment_due_at)
    assert_equal :lost, row_for(a).status
  end

  test "only my auctions, one row per auction, open first" do
    open_a = auctions(:english)
    place_bid(open_a, @me, 1_100, at: 3.minutes.ago)
    place_bid(open_a, @me, 1_300, at: 1.minute.ago)
    place_bid(auctions(:sealed), @other, 3_000)

    rows = MyBids.for(@me)
    assert_equal [ open_a ], rows.map(&:auction)
    assert_equal 1_300, rows.first.my_amount
  end
end
