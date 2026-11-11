require "test_helper"

class AuctionSellerSetupTest < ActiveSupport::TestCase
  def build(type, **over)
    base = { english: { bid_increment: 100 },
             dutch:   { floor_price: 500, price_drop: 100, drop_interval_minutes: 10 },
             sealed:  {} }.fetch(type.to_sym)
    product = Product.create!(seller: users(:seller), name: "Setup product #{SecureRandom.hex(3)}")
    Auction.new({ product: product, auction_type: type, start_price: 1000,
                  start_at: 2.hours.from_now, stop_at: 1.day.from_now + 2.hours }.merge(base).merge(over))
  end

  def ok?(auction) = auction.valid?(:seller_setup)

  test "a valid auction of each type passes" do
    %w[english dutch sealed].each { |t| assert ok?(build(t)), "#{t}: #{build(t).tap { |a| a.valid?(:seller_setup) }.errors.full_messages}" }
  end

  test "rules only run in the seller_setup context" do
    past = build("english", start_at: 1.day.ago, stop_at: 1.hour.ago, start_price: 5)
    assert past.valid?, "default context must stay permissive for fixtures and jobs"
    assert_not ok?(past)
  end

  test "type is required" do
    assert_not ok?(build("english", auction_type: nil))
  end

  test "starting price must be at least 100" do
    assert ok?(build("sealed", start_price: 100))
    assert_not ok?(build("sealed", start_price: 99))
  end

  test "reserve must be at least the starting price, and is optional" do
    assert ok?(build("sealed", reserve_price: nil))
    assert ok?(build("sealed", reserve_price: 1000))
    assert_not ok?(build("sealed", reserve_price: 999))
  end

  test "start must be at least one hour from now" do
    assert_not ok?(build("sealed", start_at: 59.minutes.from_now, stop_at: 1.day.from_now))
    assert ok?(build("sealed", start_at: 61.minutes.from_now, stop_at: 1.day.from_now))
  end

  test "duration must be between 1 hour and 14 days" do
    start = 2.hours.from_now
    assert_not ok?(build("sealed", start_at: start, stop_at: start + 59.minutes))
    assert ok?(build("sealed", start_at: start, stop_at: start + 1.hour))
    assert ok?(build("sealed", start_at: start, stop_at: start + 14.days))
    assert_not ok?(build("sealed", start_at: start, stop_at: start + 14.days + 1.minute))
  end

  test "english increment defaults to 100 and needs at least 10" do
    a = build("english", bid_increment: nil)
    assert ok?(a)
    assert_equal 100, a.bid_increment
    assert ok?(build("english", bid_increment: 10))
    assert_not ok?(build("english", bid_increment: 9))
  end

  test "dutch needs floor below start, a drop and an interval of 1-60 minutes" do
    assert_not ok?(build("dutch", floor_price: nil))
    assert_not ok?(build("dutch", floor_price: 0))
    assert_not ok?(build("dutch", floor_price: 1000)), "floor equal to start"
    assert ok?(build("dutch", floor_price: 999, price_drop: 1))
    assert_not ok?(build("dutch", price_drop: nil))
    assert_not ok?(build("dutch", price_drop: 0))
    assert_not ok?(build("dutch", floor_price: 900, price_drop: 101)), "drop bigger than the gap"
    assert ok?(build("dutch", floor_price: 900, price_drop: 100))
    assert_not ok?(build("dutch", drop_interval_minutes: 0))
    assert ok?(build("dutch", drop_interval_minutes: 1))
    assert ok?(build("dutch", drop_interval_minutes: 60))
    assert_not ok?(build("dutch", drop_interval_minutes: 61))
  end

  test "fields that belong to another type are dropped" do
    a = build("sealed", floor_price: 5, price_drop: 5, drop_interval_minutes: 5, bid_increment: 5)
    assert ok?(a)
    assert_nil a.floor_price
    assert_nil a.price_drop
    assert_equal 100, a.bid_increment
    e = build("english", floor_price: 5, price_drop: 5, drop_interval_minutes: 5)
    assert ok?(e)
    assert_nil e.floor_price
  end

  test "current price follows the starting price while there are no bids" do
    a = build("sealed")
    a.current_price = 1
    ok?(a)
    assert_equal 1000, a.current_price
  end
end
