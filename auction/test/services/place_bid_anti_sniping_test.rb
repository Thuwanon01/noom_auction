require "test_helper"

class PlaceBidAntiSnipingTest < ActiveSupport::TestCase
  setup do
    @now = Time.current.change(usec: 0)
    @auction = auctions(:english)
    @auction.update!(start_at: @now - 1.hour, stop_at: @now + 10.minutes)
    @bidders = [ users(:buyer), users(:other_buyer) ]
    @price = @auction.current_price
  end

  def bid_at(now, user: @bidders.rotate!.first)
    @price += 100
    PlaceBid.call(user: user, auction: @auction, amount: @price, idempotency_key: SecureRandom.uuid, now: now)
  end

  test "a bid 2:01 before the end does not extend" do
    stop = @auction.stop_at
    assert bid_at(stop - 121.seconds).success?
    assert_equal stop, @auction.reload.stop_at
    assert_equal 0, @auction.extension_count
  end

  test "a bid exactly 2:00 before the end extends" do
    stop = @auction.stop_at
    assert bid_at(stop - 120.seconds).success?
    assert_equal stop + 2.minutes, @auction.reload.stop_at
  end

  test "a bid 1:59 before the end extends stop_at by 2 minutes" do
    stop = @auction.stop_at
    result = bid_at(stop - 119.seconds)
    assert result.success?
    assert result.extended?
    assert_equal stop + 2.minutes, @auction.reload.stop_at
    assert_equal 1, @auction.extension_count
  end

  test "the 11th bid in the window does not extend any more" do
    10.times do |i|
      assert bid_at(@auction.stop_at - 1.second).success?, "bid #{i + 1} failed"
    end
    assert_equal 10, @auction.reload.extension_count
    stop = @auction.stop_at

    result = bid_at(stop - 1.second)
    assert result.success?
    assert_not result.extended?
    assert_equal stop, @auction.reload.stop_at
    assert_equal 10, @auction.extension_count
  end

  test "a rejected bid in the window does not extend" do
    stop = @auction.stop_at
    PlaceBid.call(user: users(:buyer), auction: @auction, amount: 1, idempotency_key: "x", now: stop - 1.second)
    assert_equal stop, @auction.reload.stop_at
  end
end
