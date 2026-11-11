require "test_helper"

# M3.1 (#27): derived catalog fields.
class AuctionCatalogTest < ActiveSupport::TestCase
  include CatalogFactory

  setup do
    @now = Time.current.change(usec: 0)
    @auction = create_auction(start_at: @now, stop_at: @now + 1.hour)
  end

  test "phase is upcoming just before start_at" do
    assert_equal "upcoming", @auction.phase(@now - 1.second)
  end

  test "phase is live at the exact start_at" do
    assert_equal "live", @auction.phase(@now)
  end

  test "phase is live just before stop_at" do
    assert_equal "live", @auction.phase(@now + 1.hour - 1.second)
  end

  test "phase is ended at the exact stop_at, matching live?" do
    assert_equal "ended", @auction.phase(@now + 1.hour)
    assert_not @auction.live?(@now + 1.hour)
  end

  test "a closed auction is ended even before stop_at" do
    @auction.update!(status: "sold")
    assert_equal "ended", @auction.phase(@now + 1.minute)
  end

  test "SQL phase scopes agree with #phase at the boundaries" do
    [ @now - 1.second, @now, @now + 1.hour - 1.second, @now + 1.hour ].each do |t|
      phase = @auction.phase(t)
      ids = { "live" => Auction.live_at(t), "upcoming" => Auction.upcoming_at(t), "ended" => Auction.ended_at(t) }
      ids.each do |name, scope|
        assert_equal name == phase, scope.exists?(@auction.id), "#{name} scope at #{t - @now}s"
      end
      sql_phase = Auction.where(id: @auction.id).pick(Arel.sql(Auction.phase_sql(t)))
      assert_equal phase, sql_phase
    end
  end

  test "current_price starts at start_price; next_min_bid adds the increment" do
    assert_equal 1_000, @auction.current_price
    assert_equal 1_100, @auction.next_min_bid
    assert_equal 0, @auction.bid_count
  end

  test "sealed auctions list the start price" do
    sealed = auctions(:sealed)
    sealed.update!(current_price: 9_999)
    assert_equal sealed.start_price, sealed.listed_price
  end

  test "publicly_listed hides private products and cancelled auctions" do
    assert_not Auction.publicly_listed.exists?(auctions(:draft).id)
    assert Auction.publicly_listed.exists?(auctions(:english).id)
    auctions(:english).update!(status: "cancelled")
    assert_not Auction.publicly_listed.exists?(auctions(:english).id)
  end

  test "winning_price is the top bid when reserve is met" do
    place_bid(@auction, users(:buyer), 1_200)
    place_bid(@auction, users(:other_buyer), 1_500)
    assert_equal 1_500, @auction.winning_price
  end

  test "winning_price is nil when there are no bids, reserve not met, or no_winner" do
    assert_nil @auction.winning_price
    @auction.update!(reserve_price: 2_000)
    place_bid(@auction, users(:buyer), 1_500)
    assert_nil @auction.winning_price
    @auction.update!(reserve_price: nil, status: "no_winner")
    assert_nil @auction.winning_price
  end
end

class AuctionDutchListedPriceTest < ActiveSupport::TestCase
  setup { @dutch = auctions(:dutch) } # 10,000, -500 every 10 min, floor 5,000

  test "an open Dutch auction lists the price at that moment, not the stored current_price" do
    now = @dutch.start_at + 25.minutes
    assert_equal 9_000, @dutch.listed_price(now)
    assert_equal 9_000, @dutch.next_min_bid(now)
  end

  test "a sold Dutch auction lists the price it sold at" do
    @dutch.update!(status: :sold, current_price: 7_500, closed_at: Time.current)
    assert_equal 7_500, @dutch.listed_price(@dutch.start_at + 100.minutes)
  end
end
