require "test_helper"

class AuctionTest < ActiveSupport::TestCase
  test "new auctions start open with no extensions" do
    a = auctions(:english)
    assert a.open?
    assert_equal 0, a.extension_count
    assert_nil a.winner
    assert_nil a.closed_at
  end

  test "auction_type enum covers the three types" do
    assert_equal %w[english dutch sealed], Auction.auction_types.keys
  end

  test "status enum covers closing outcomes" do
    assert_equal %w[open sold no_winner unsold cancelled], Auction.statuses.keys
  end

  test "money fields are whole baht" do
    a = auctions(:english)
    a.start_price = 99.5
    assert_not a.valid?
  end

  test "winner and seller associations" do
    a = auctions(:english)
    a.update!(winner: users(:buyer))
    assert_equal users(:buyer), a.reload.winner
    assert_equal users(:seller), a.seller
  end

  test "live? uses start_at <= now < stop_at" do
    a = auctions(:english)
    now = Time.current
    a.start_at = now
    a.stop_at = now + 1.minute
    assert a.live?(now)
    a.stop_at = now
    assert_not a.live?(now)
    a.start_at = now + 1.second
    a.stop_at = now + 1.hour
    assert_not a.live?(now)
  end

  test "has many bids" do
    a = auctions(:english)
    a.bids.create!(user: users(:buyer), amount: 1100, idempotency_key: "x")
    assert_equal 1, a.bids.count
  end
end
