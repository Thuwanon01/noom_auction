require "test_helper"

class PlaceBidTest < ActiveSupport::TestCase
  setup do
    @auction = auctions(:english) # current 1,000, increment 100
    @buyer = users(:buyer)
    @other = users(:other_buyer)
  end

  def place(user: @buyer, amount: 1_100, key: SecureRandom.uuid, **opts)
    PlaceBid.call(user: user, auction: @auction, amount: amount, idempotency_key: key, **opts)
  end

  test "a valid bid is saved and becomes the current price" do
    result = place(amount: 1_100)
    assert result.success?
    assert_equal 1_100, result.bid.amount
    assert_equal 1_100, @auction.reload.current_price
    assert_equal 1, @auction.bids.count
  end

  test "accepts a whole-number string amount" do
    assert place(amount: "1200").success?
    assert_equal 1_200, @auction.reload.current_price
  end

  test "rejects a bid below current price + increment" do
    result = place(amount: 1_099)
    assert_not result.success?
    assert_equal :below_minimum, result.error
    assert_equal "The minimum bid is ฿1,100", result.message
    assert_equal 1_100, result.minimum
    assert_equal 0, @auction.bids.count
  end

  [ 0, -100, "abc", "1100.5", 1100.5, nil, "" ].each do |bad|
    test "rejects invalid amount #{bad.inspect}" do
      result = place(amount: bad)
      assert_equal :invalid_amount, result.error
      assert_equal "Enter a valid amount", result.message
    end
  end

  test "rejects with price changed when another bid arrived after the client loaded the price" do
    place(user: @other, amount: 1_500)
    result = place(amount: 1_100, expected_price: 1_000)
    assert_equal :price_changed, result.error
    assert_equal "Price changed. The new minimum is ฿1,600", result.message
    assert_equal 1_600, result.minimum
  end

  test "an amount still above the new minimum is accepted even if the price changed" do
    place(user: @other, amount: 1_500)
    assert place(amount: 2_000, expected_price: 1_000).success?
  end

  test "the highest bidder cannot bid again until outbid" do
    place(amount: 1_100)
    result = place(amount: 1_500)
    assert_equal :already_highest, result.error
    assert_equal "You are already the highest bidder", result.message

    place(user: @other, amount: 1_600)
    assert place(amount: 1_700).success?
  end

  test "the same idempotency key returns the original bid and does not create a second one" do
    first = place(amount: 1_100, key: "dup")
    again = place(amount: 1_100, key: "dup")
    assert again.success?
    assert again.replayed?
    assert_equal first.bid, again.bid
    assert_equal 1, @auction.bids.count
  end

  test "eligibility failures come from BidPolicy" do
    result = place(user: users(:seller))
    assert_equal :own_item, result.error
    assert_equal "You cannot bid on your own item", result.message
  end

  test "over the bid limit is rejected" do
    @other.update!(credit_grade: "D")
    result = place(user: @other, amount: 10_100)
    assert_equal :over_limit, result.error
  end

  test "a bid after stop_at says the auction has just ended" do
    @auction.update!(stop_at: 1.second.ago)
    result = place
    assert_equal :auction_ended, result.error
    assert_equal "This auction has just ended", result.message
  end

  test "a bid before start_at is not open" do
    @auction.update!(start_at: 1.hour.from_now)
    assert_equal :not_live, place.error
  end

  test "reports the previous leader so they can be notified" do
    place(user: @other, amount: 1_100)
    result = place(amount: 1_200)
    assert_equal @other, result.previous_leader
  end

  test "only english auctions are accepted" do
    @auction = auctions(:sealed)
    assert_equal :wrong_auction_type, place(amount: 5_000).error
  end
end

class PlaceBidConcurrencyTest < ActiveSupport::TestCase
  self.use_transactional_tests = false

  teardown do
    Notification.delete_all
    Bid.delete_all
  end

  test "two equal bids at the same time cannot both win" do
    auction = auctions(:english)
    users = [ users(:buyer), users(:other_buyer) ]
    gate = Queue.new

    threads = users.map do |user|
      Thread.new do
        ActiveRecord::Base.connection_pool.with_connection do
          gate.pop
          PlaceBid.call(user: user, auction: Auction.find(auction.id), amount: 1_100, idempotency_key: SecureRandom.uuid)
        end
      end
    end
    2.times { gate << :go }
    results = threads.map(&:value)

    assert_equal 1, results.count(&:success?)
    assert_equal 1, auction.bids.count
    assert_equal 1_100, auction.reload.current_price
  ensure
    auction&.update_columns(current_price: 1_000)
  end
end
