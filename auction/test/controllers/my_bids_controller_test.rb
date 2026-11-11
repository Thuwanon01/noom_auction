require "test_helper"

class MyBidsControllerTest < ActionDispatch::IntegrationTest
  include CatalogFactory

  test "guests are sent to log in" do
    get my_bids_path
    assert_redirected_to login_path
  end

  test "lists only my auctions with status and link" do
    mine = auctions(:english)
    place_bid(mine, users(:buyer), 1_100)
    place_bid(auctions(:sealed), users(:other_buyer), 3_000)

    sign_in_as users(:buyer)
    get my_bids_path
    assert_response :success
    assert_select ".my-bid", 1
    assert_select ".my-bid a[href=?]", auction_path(mine), text: "Vintage Film Camera"
    assert_select ".my-bid [data-status=winning]", text: "Winning"
    assert_select ".my-bid", text: /Oil Painting/, count: 0
  end

  test "won shows the payment deadline" do
    a = auctions(:english)
    a.update_columns(stop_at: 1.minute.ago, reserve_price: nil)
    place_bid(a, users(:buyer), 1_500, at: 2.minutes.ago)
    CloseAuction.call(a)

    sign_in_as users(:buyer)
    get my_bids_path
    assert_select ".my-bid [data-status=won]", text: "Won"
    assert_select ".my-bid", text: /ชำระภายใน/
  end

  test "empty state" do
    sign_in_as users(:buyer)
    get my_bids_path
    assert_select ".empty", text: /ยังไม่ได้เสนอราคา/
    assert_select ".empty a[href=?]", auctions_path
  end

  test "sidebar links to My Bids" do
    get auctions_path
    assert_select ".shop__nav a[href=?]", my_bids_path, text: "My Bids"
  end
end
