require "test_helper"

class BuyNowTest < ActiveSupport::TestCase
  setup do
    @auction = auctions(:dutch)
    @now = @auction.start_at + 25.minutes # price 9,000
    @buyer = users(:buyer)
  end

  def buy(user: @buyer, expected_price: 9_000, key: SecureRandom.uuid, now: @now)
    BuyNow.call(user: user, auction: @auction, expected_price: expected_price, idempotency_key: key, now: now)
  end

  test "buys at the server price, wins and closes the auction" do
    result = buy
    assert result.success?
    assert_equal 9_000, result.bid.amount
    @auction.reload
    assert @auction.sold?
    assert_equal @buyer, @auction.winner
    assert_equal 9_000, @auction.current_price
    assert_equal @now, @auction.closed_at
    assert_equal "sold", @auction.product.reload.status
  end

  test "uses the server price, never the client price" do
    result = buy(expected_price: 1)
    assert_not result.success?
    assert_equal 0, @auction.bids.count
  end

  test "a stale client price returns the new price and asks again" do
    result = buy(expected_price: 9_500)
    assert_equal :price_changed, result.error
    assert_equal 9_000, result.price
    assert_equal "Price changed. The new price is ฿9,000", result.message
    assert @auction.reload.open?
  end

  test "confirming again at the new price succeeds" do
    buy(expected_price: 9_500)
    assert buy(expected_price: 9_000).success?
  end

  test "a second buyer sees Sold" do
    buy
    result = buy(user: users(:other_buyer))
    assert_equal :sold, result.error
    assert_equal "Sold", result.message
    assert_equal 1, @auction.bids.count
  end

  test "the same idempotency key replays the original purchase" do
    first = buy(key: "k")
    again = buy(key: "k")
    assert again.success?
    assert again.replayed?
    assert_equal first.bid, again.bid
  end

  test "at the floor the auction stays open at the floor price until stop_at" do
    late = @auction.stop_at - 1.minute
    assert buy(expected_price: 5_000, now: late).success?
  end

  test "after stop_at it has just ended" do
    assert_equal :auction_ended, buy(expected_price: 5_000, now: @auction.stop_at).error
  end

  test "the bid limit applies to Dutch purchases: at the limit is allowed" do
    @buyer.update!(credit_grade: "D") # limit 10,000
    assert buy(expected_price: 10_000, now: @auction.start_at).success?
  end

  test "the bid limit applies to Dutch purchases: over the limit is rejected" do
    @buyer.update!(credit_grade: "D")
    @auction.update!(start_price: 10_500)
    assert_equal :over_limit, buy(expected_price: 10_500, now: @auction.start_at).error
  end

  test "the seller cannot buy" do
    assert_equal :own_item, buy(user: users(:seller)).error
  end

  test "only dutch auctions" do
    @auction = auctions(:english)
    assert_equal :wrong_auction_type, buy.error
  end
end

class BuyNowRaceTest < ActiveSupport::TestCase
  self.use_transactional_tests = false

  teardown do
    Notification.delete_all
    Bid.delete_all
    auctions(:dutch).update_columns(status: "open", winner_id: nil, closed_at: nil, current_price: 10_000)
    products(:watch).update_columns(status: "live")
  end

  test "two buyers racing: exactly one wins" do
    auction = auctions(:dutch)
    now = auction.start_at + 5.minutes
    gate = Queue.new
    threads = [ users(:buyer), users(:other_buyer) ].map do |user|
      Thread.new do
        ActiveRecord::Base.connection_pool.with_connection do
          gate.pop
          BuyNow.call(user: user, auction: Auction.find(auction.id), expected_price: 10_000, idempotency_key: SecureRandom.uuid, now: now)
        end
      end
    end
    2.times { gate << :go }
    results = threads.map(&:value)

    assert_equal 1, results.count(&:success?)
    assert_equal [ :sold ], results.reject(&:success?).map(&:error)
    assert_equal 1, auction.bids.count
  end
end
