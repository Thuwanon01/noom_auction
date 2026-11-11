require "test_helper"

# M3.3 (#29) and M3.5 (#31).
class AuctionSearchTest < ActiveSupport::TestCase
  include CatalogFactory

  setup do
    Auction.delete_all
    Bid.delete_all
    @now = Time.current
    @camera = create_auction(name: "Nikon FM2 Camera", category: "camera", type: "english", price: 4_500, stop_at: @now + 5.hours)
    @watch  = create_auction(name: "Seiko Watch", category: "watch", type: "dutch", price: 900, stop_at: @now + 1.day)
    @art    = create_auction(name: "Oil Painting", category: "art", type: "sealed", price: 2_500, current_price: 8_000,
                             start_at: @now + 1.day, stop_at: @now + 3.days)
    @old    = create_auction(name: "Old Teak Table", category: "furniture", type: "english", price: 150_000,
                             start_at: @now - 3.days, stop_at: @now - 1.day)
    @hidden = create_auction(name: "Draft Camera", category: "camera", product_status: "draft")
  end

  def ids(params = {}) = AuctionSearch.new(params, now: @now).relation.map(&:id)

  test "no params lists every public auction, live first then upcoming then ended, by stop_at" do
    assert_equal [ @camera.id, @watch.id, @art.id, @old.id ], ids
  end

  test "search matches product name case-insensitively" do
    assert_equal [ @camera.id ], ids(q: "nikon")
    assert_equal [ @camera.id ], ids(q: "  NIKON ")
  end

  test "search matches the Thai category label" do
    assert_equal [ @watch.id ], ids(q: "นาฬิกา")
  end

  test "search treats LIKE wildcards literally" do
    assert_empty ids(q: "%")
  end

  test "status filter" do
    assert_equal [ @camera.id, @watch.id ], ids(status: "live")
    assert_equal [ @art.id ], ids(status: "upcoming")
    assert_equal [ @old.id ], ids(status: "ended")
  end

  test "type filter is multi-select" do
    assert_equal [ @watch.id ], ids(type: [ "dutch" ])
    assert_equal [ @watch.id, @art.id ], ids(type: %w[dutch sealed])
    assert_equal [ @watch.id, @art.id ], ids(type: "dutch,sealed")
  end

  test "category filter is multi-select" do
    assert_equal [ @camera.id, @art.id ], ids(category: %w[camera art])
  end

  test "price ranges use the listed price (start price for sealed)" do
    assert_equal [ @watch.id ], ids(price: "0-1000")
    assert_equal [ @art.id ], ids(price: "1001-3000")
    assert_equal [ @camera.id ], ids(price: "3001-10000")
    assert_equal [ @old.id ], ids(price: "100001-")
  end

  test "filters combine with AND" do
    assert_equal [ @camera.id ], ids(status: "live", type: [ "english" ])
    assert_empty ids(status: "live", category: [ "art" ])
  end

  test "price sorts" do
    assert_equal [ @watch.id, @art.id, @camera.id, @old.id ], ids(sort: "price_asc")
    assert_equal [ @old.id, @camera.id, @art.id, @watch.id ], ids(sort: "price_desc")
  end

  test "unknown values are ignored" do
    search = AuctionSearch.new({ status: "nope", type: [ "x", "dutch" ], category: "zzz", price: "1-2", sort: "drop table", page: "abc" }, now: @now)
    assert_nil search.status
    assert_equal [ "dutch" ], search.types
    assert_empty search.categories
    assert_nil search.price
    assert_equal "ending", search.sort
    assert_equal [ @watch.id ], search.relation.map(&:id)
  end

  test "params can be ActionController::Parameters" do
    params = ActionController::Parameters.new(status: "live", type: [ "english" ])
    assert_equal [ @camera.id ], AuctionSearch.new(params, now: @now).relation.map(&:id)
  end

  test "status counts apply the other filters but not status" do
    search = AuctionSearch.new({ status: "ended", type: %w[english sealed] }, now: @now)
    assert_equal({ "live" => 1, "upcoming" => 1, "ended" => 1, "all" => 3 }, search.counts)
    assert_equal 1, search.total
  end

  test "filter_params drops defaults and normalizes" do
    assert_equal({ status: "live", type: [ "dutch" ] }, AuctionSearch.new({ status: "live", type: "dutch", sort: "ending" }).filter_params)
  end

  # --- Pagination ---------------------------------------------------------

  def paged(page)
    AuctionSearch.new({ page: page }, now: @now)
  end

  test "six per page" do
    4.times { |i| create_auction(name: "Extra #{i}") }
    assert_equal 8, paged(1).total
    assert_equal 2, paged(1).total_pages
    assert_equal 6, paged(1).records.size
    assert_equal 2, paged(2).records.size
  end

  test "page 0, negative, non-numeric and beyond last are clamped" do
    4.times { |i| create_auction(name: "Extra #{i}") }
    assert_equal 1, paged("0").page
    assert_equal 1, paged("-3").page
    assert_equal 1, paged("abc").page
    assert_equal 1, paged("1.5").page
    assert_equal 2, paged("99").page
    assert_equal 2, paged("99").records.size
  end

  test "empty result is page 1 of 1" do
    search = AuctionSearch.new({ q: "nothing matches", page: "5" }, now: @now)
    assert_equal 1, search.page
    assert_equal 1, search.total_pages
    assert_empty search.records
  end
end
