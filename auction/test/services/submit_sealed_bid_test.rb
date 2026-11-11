require "test_helper"

class SubmitSealedBidTest < ActiveSupport::TestCase
  setup do
    @auction = auctions(:sealed) # start 2,000
    @buyer = users(:buyer)
    @other = users(:other_buyer)
    @now = Time.current.change(usec: 0)
  end

  def submit(user: @buyer, amount: 2_500, key: SecureRandom.uuid, now: @now)
    SubmitSealedBid.call(user: user, auction: @auction, amount: amount, idempotency_key: key, now: now)
  end

  test "submits a sealed bid" do
    result = submit
    assert result.success?
    assert_equal 2_500, result.bid.amount
    assert_equal 1, result.bid_count
  end

  test "the starting price itself is accepted" do
    assert submit(amount: 2_000).success?
  end

  test "below the starting price is rejected" do
    result = submit(amount: 1_999)
    assert_equal :below_minimum, result.error
    assert_equal "The minimum bid is ฿2,000", result.message
  end

  test "invalid amounts are rejected" do
    assert_equal :invalid_amount, submit(amount: "12.5").error
  end

  test "over the bid limit is rejected" do
    @buyer.update!(credit_grade: "C")
    assert_equal :over_limit, submit(amount: 50_001).error
  end

  test "revising replaces the amount; still one bid per user" do
    submit(amount: 2_500)
    result = submit(amount: 3_000, now: @now + 1.minute)
    assert result.success?
    assert result.revised?
    assert_equal 1, @auction.bids.where(user: @buyer).count
    assert_equal 3_000, @auction.bids.find_by(user: @buyer).amount
  end

  test "a revise resets placed_at to the revise time" do
    submit(amount: 2_500)
    submit(amount: 3_000, now: @now + 1.minute)
    assert_equal @now + 1.minute, @auction.bids.find_by(user: @buyer).placed_at
  end

  test "cannot revise after stop_at" do
    submit(amount: 2_500)
    result = submit(amount: 3_000, now: @auction.stop_at)
    assert_equal :auction_ended, result.error
    assert_equal 2_500, @auction.bids.find_by(user: @buyer).amount
  end

  test "the same idempotency key replays without changing the bid" do
    first = submit(amount: 2_500, key: "k")
    again = submit(amount: 2_500, key: "k")
    assert again.replayed?
    assert_equal first.bid, again.bid
    assert_equal 1, @auction.bids.count
  end

  test "tie: the earliest bid wins in ranking" do
    submit(user: @other, amount: 3_000, now: @now)
    submit(user: @buyer, amount: 3_000, now: @now + 1.second)
    assert_equal @other, @auction.bids.ranked.first.user
  end

  test "tie: revising up to the leading amount does not keep the early timestamp" do
    submit(user: @buyer, amount: 2_100, now: @now)
    submit(user: @other, amount: 3_000, now: @now + 1.minute)
    submit(user: @buyer, amount: 3_000, now: @now + 2.minutes)
    assert_equal @other, @auction.bids.ranked.first.user
  end

  test "the response never carries other bidders' amounts" do
    submit(user: @other, amount: 9_999)
    result = submit(user: @buyer, amount: 2_500)
    assert_equal @buyer, result.bid.user
    assert_not_includes result.to_h.except(:bid).values, 9_999
    assert_equal 2, result.bid_count
  end

  test "only sealed auctions" do
    @auction = auctions(:english)
    assert_equal :wrong_auction_type, submit.error
  end
end

class SealedBidVisibilityTest < ActiveSupport::TestCase
  setup do
    @auction = auctions(:sealed)
    @mine = @auction.bids.create!(user: users(:buyer), amount: 2_500, idempotency_key: "a")
    @theirs = @auction.bids.create!(user: users(:other_buyer), amount: 3_000, idempotency_key: "b")
  end

  test "before close a bidder sees only their own bid" do
    assert_equal [ @mine ], @auction.bids_visible_to(users(:buyer)).to_a
  end

  test "before close guests and the seller see no bids" do
    assert_empty @auction.bids_visible_to(nil)
    assert_empty @auction.bids_visible_to(users(:seller))
  end

  test "after close everyone sees all bids, newest first" do
    @auction.update!(status: :sold, closed_at: Time.current)
    assert_equal [ @theirs, @mine ], @auction.bids_visible_to(nil).to_a
  end

  test "english bids are always visible, newest first" do
    english = auctions(:english)
    b1 = english.bids.create!(user: users(:buyer), amount: 1_100, idempotency_key: "c", placed_at: 1.minute.ago)
    b2 = english.bids.create!(user: users(:other_buyer), amount: 1_200, idempotency_key: "d")
    assert_equal [ b2, b1 ], english.bids_visible_to(nil).to_a
  end
end
