require "test_helper"

class BidPolicyTest < ActiveSupport::TestCase
  setup do
    @now = Time.current.change(usec: 0)
    @auction = auctions(:english)
    @auction.update!(start_at: @now - 1.hour, stop_at: @now + 1.hour)
    @buyer = users(:buyer) # grade B
  end

  def check(user: @buyer, auction: @auction, amount: 1_100, now: @now)
    BidPolicy.new(user: user, auction: auction, amount: amount, now: now).check
  end

  test "allows an eligible bid" do
    result = check
    assert result.allowed?
    assert_nil result.reason
    assert_nil result.message
  end

  test "rejects a guest" do
    result = check(user: nil)
    assert_not result.allowed?
    assert_equal :not_logged_in, result.reason
    assert_equal "Log in to bid", result.message
  end

  test "rejects a user who has not completed onboarding" do
    result = check(user: users(:newbie))
    assert_equal :onboarding_incomplete, result.reason
    assert_equal "Complete your profile to bid", result.message
  end

  test "rejects the seller" do
    result = check(user: users(:seller))
    assert_equal :own_item, result.reason
    assert_equal "You cannot bid on your own item", result.message
  end

  test "auction is live exactly at start_at" do
    @auction.update!(start_at: @now)
    assert check.allowed?
  end

  test "auction is not live one second before start_at" do
    @auction.update!(start_at: @now + 1.second)
    result = check
    assert_equal :not_live, result.reason
    assert_equal "This auction is not open for bidding", result.message
  end

  test "auction is live one second before stop_at" do
    @auction.update!(stop_at: @now + 1.second)
    assert check.allowed?
  end

  test "auction is not live exactly at stop_at" do
    @auction.update!(stop_at: @now)
    assert_equal :not_live, check.reason
  end

  test "auction is not live once closed even before stop_at" do
    @auction.update!(status: :sold)
    assert_equal :not_live, check.reason
  end

  test "grade A has no limit" do
    assert check(user: users(:seller_as_buyer_a), amount: 10_000_000).allowed?
  end

  {
    "B" => 200_000,
    "C" => 50_000,
    "D" => 10_000
  }.each do |grade, limit|
    test "grade #{grade} allows exactly #{limit}" do
      @buyer.update!(credit_grade: grade)
      assert check(amount: limit).allowed?
    end

    test "grade #{grade} rejects #{limit + 1} with the real limit in the message" do
      @buyer.update!(credit_grade: grade)
      result = check(amount: limit + 1)
      assert_equal :over_limit, result.reason
      assert_equal "Over your bid limit. Your limit is ฿#{limit.to_fs(:delimited)}", result.message
      assert_equal limit, result.limit
    end
  end

  test "a user without a grade gets the lowest limit" do
    @buyer.update!(credit_grade: nil)
    assert_equal :over_limit, check(amount: 10_001).reason
  end

  test "without an amount only the account and auction rules are checked" do
    assert check(amount: nil).allowed?
  end

  test "bid_limit_for exposes the limit per grade" do
    assert_nil BidPolicy.bid_limit_for(users(:seller_as_buyer_a))
    assert_equal 200_000, BidPolicy.bid_limit_for(@buyer)
  end
end
