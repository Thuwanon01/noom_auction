require "test_helper"

class AuctionsControllerTest < ActionDispatch::IntegrationTest
  include CatalogFactory

  # --- List (M3.1, M3.4, M3.5, M3.6) -----------------------------------------

  test "index renders public auctions from the database" do
    get auctions_path
    assert_response :success
    assert_select ".card", 3
    assert_select ".card__title", text: "Vintage Film Camera"
    assert_select ".card__title", text: "Unreviewed Draft Lamp", count: 0
  end

  test "index shows status tab counts" do
    get auctions_path
    assert_select ".toolbar__chips .chip", text: /กำลังประมูล\s+3/
  end

  test "filters come from the query string and show removable chips" do
    get auctions_path(type: [ "sealed" ], q: "oil")
    assert_select ".card", 1
    assert_select ".active-filters .chip--removable", 2
    assert_select ".active-filters a[href=?]", "/auctions?q=oil", text: /ประมูลซองปิด/
    assert_select ".active-filters__clear[href=?]", "/auctions"
  end

  test "pagination keeps the other params and drops nothing" do
    6.times { |i| create_auction(name: "Extra #{i}", type: "english") }
    get auctions_path(type: [ "english" ], sort: "price_asc")
    assert_select ".card", 6
    assert_select ".pager a[rel=next][href=?]", "/auctions?page=2&sort=price_asc&type%5B%5D=english"
  end

  test "out-of-range page is clamped" do
    get auctions_path(page: 99)
    assert_response :success
    assert_select ".card", 3
  end

  test "no results state offers clear all" do
    get auctions_path(q: "does not exist", sort: "price_desc")
    assert_select ".empty p", text: "ไม่พบรายการที่ตรงกับเงื่อนไข"
    assert_select ".empty a[href=?]", "/auctions?sort=price_desc", text: "ล้างตัวกรองทั้งหมด"
  end

  test "no auctions yet state" do
    Bid.delete_all
    Auction.delete_all
    get auctions_path
    assert_select ".empty p", text: "ยังไม่มีรายการประมูล"
    assert_select ".empty a", count: 0
  end

  test "load error keeps the page shell and offers retry" do
    broken = Class.new(AuctionSearch) { def records = raise(ActiveRecord::ConnectionNotEstablished, "db down") }
    build = ->(*args, **opts) { broken.allocate.tap { |s| s.send(:initialize, *args, **opts) } }
    with_stubbed(AuctionSearch, :new, build) do
      get auctions_path(status: "live")
    end
    assert_response :service_unavailable
    assert_select ".shop__title", text: "Event"
    assert_select "[role=alert] p", text: "โหลดข้อมูลไม่สำเร็จ"
    assert_select "[role=alert] a[href=?]", "/auctions?status=live", text: "ลองอีกครั้ง"
  end

  # --- Detail (M3.7, M3.8, M3.9) ---------------------------------------------

  test "unknown id returns 404 with a link back" do
    get auction_path(id: 999_999)
    assert_response :not_found
    assert_select "a[href=?]", auctions_path
  end

  test "a private product's auction is not found" do
    get auction_path(auctions(:draft))
    assert_response :not_found
  end

  test "price box values match the model" do
    auction = auctions(:english)
    place_bid(auction, users(:buyer), 1_300)
    auction.update!(current_price: 1_300)
    get auction_path(auction)
    assert_response :success
    assert_select "[data-testid=current-price]", text: "฿1,300"
    assert_select "[data-testid=next-min-bid]", text: "฿#{auction.next_min_bid.to_fs(:delimited)}"
    assert_select "[data-testid=bid-count]", text: auction.bid_count.to_s
    assert_select "[data-controller=countdown]"
  end

  test "header shows category, condition and masked seller" do
    get auction_path(auctions(:english))
    assert_select ".facts dd", text: "กล้อง"
    assert_select ".facts dd", text: "สภาพดี"
    assert_select ".facts dd", text: "So***"
    assert_no_match "Somchai Seller", response.body
  end

  test "bid history is newest first with masked usernames" do
    auction = auctions(:english)
    place_bid(auction, users(:buyer), 1_100, at: 2.minutes.ago)
    place_bid(auction, users(:other_buyer), 1_200, at: 1.minute.ago)
    get auction_path(auction)
    rows = css_select(".table tbody tr")
    assert_equal [ "Ch***", "Bu***" ], rows.map { |r| r.css("td")[1].text }
    assert_no_match "Bua Buyer", response.body
  end

  test "sealed bid amounts are not in the response before close" do
    auction = auctions(:sealed)
    place_bid(auction, users(:buyer), 7_654_321)
    get auction_path(auction)
    assert_response :success
    assert_no_match "7,654,321", response.body
    assert_no_match "7654321", response.body
    assert_select ".table", count: 0
    assert_select "[data-testid=bid-count]", text: "1"
  end

  test "sealed bid history appears once the auction ends" do
    auction = auctions(:sealed)
    place_bid(auction, users(:buyer), 7_654_321, at: 2.hours.ago)
    auction.update_columns(stop_at: 1.minute.ago)
    get auction_path(auction)
    assert_select ".table td", text: "฿7,654,321"
  end

  test "action area: guest on live sees log in to bid" do
    get auction_path(auctions(:english))
    assert_select ".action-area[data-state=login_to_bid] a", text: "Log in to bid"
  end

  test "action area: signed-in seller sees this is your item" do
    sign_in_as users(:seller)
    get auction_path(auctions(:english))
    assert_select ".action-area[data-state=own_item]", text: /This is your item/
    assert_select ".action-area form", count: 0
  end

  test "action area: not-onboarded user is asked to complete profile" do
    sign_in_as users(:newbie)
    get auction_path(auctions(:english))
    assert_select ".action-area[data-state=complete_profile] a", text: "Complete your profile to bid"
  end

  test "ended result shows winning price or no winner" do
    auction = auctions(:english)
    place_bid(auction, users(:buyer), 1_500, at: 2.hours.ago)
    auction.update_columns(stop_at: 1.minute.ago)
    get auction_path(auction)
    assert_select ".result__price", text: "ราคาที่ชนะ ฿1,500"

    auction.update_columns(reserve_price: 5_000)
    get auction_path(auction)
    assert_select ".result__price", text: "ไม่มีผู้ชนะ"
  end
end
