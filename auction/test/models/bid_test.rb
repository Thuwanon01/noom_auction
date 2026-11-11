require "test_helper"

class BidTest < ActiveSupport::TestCase
  setup do
    @auction = auctions(:english)
    @buyer = users(:buyer)
  end

  def build_bid(**attrs)
    Bid.new({ auction: @auction, user: @buyer, amount: 1100, placed_at: Time.current, idempotency_key: "k1" }.merge(attrs))
  end

  test "valid bid saves" do
    assert build_bid.save
  end

  test "amount must be a positive whole number" do
    assert_not build_bid(amount: 0).valid?
    assert_not build_bid(amount: -5).valid?
    assert_not build_bid(amount: 100.5).valid?
    assert_not build_bid(amount: nil).valid?
  end

  test "idempotency key is unique per user and auction" do
    build_bid.save!
    dup = build_bid
    assert_not dup.valid?
    assert_includes dup.errors[:idempotency_key], "has already been taken"
  end

  test "database rejects a duplicate idempotency key even when validations are skipped" do
    build_bid.save!
    assert_raises(ActiveRecord::RecordNotUnique) { build_bid.save!(validate: false) }
  end

  test "same idempotency key is allowed for a different user or auction" do
    build_bid.save!
    assert build_bid(user: users(:other_buyer)).save
    assert build_bid(auction: auctions(:sealed)).save
  end

  test "placed_at defaults to now" do
    bid = build_bid(placed_at: nil)
    bid.save!
    assert_in_delta Time.current, bid.placed_at, 2
  end

  test "ranked orders by amount desc then placed_at asc" do
    t = Time.current
    early = build_bid(amount: 1500, placed_at: t - 10, idempotency_key: "a")
    late  = build_bid(amount: 1500, placed_at: t, idempotency_key: "b", user: users(:other_buyer))
    low   = build_bid(amount: 1200, placed_at: t - 20, idempotency_key: "c")
    [ late, low, early ].each(&:save!)
    assert_equal [ early, late, low ], @auction.bids.ranked.to_a
  end
end
