require "application_system_test_case"

# M4.7 (#43) acceptance: buy at the current price; a second user sees Sold.
class DutchBuyNowTest < ApplicationSystemTestCase
  setup do
    @auction = auctions(:dutch)
    @auction.update_columns(start_at: 25.minutes.ago) # 9,000
  end

  test "buy at the current price, then a second user sees Sold" do
    sign_in_as users(:buyer)
    visit auction_path(@auction)
    click_button "Buy now at ฿9,000"
    assert_selector ".bid-flash--success", text: "You bought this item for ฿9,000"

    sign_in_as users(:other_buyer)
    visit auction_path(@auction)
    assert_selector ".result", text: "Sold"
    assert_no_button(/Buy now/)
  end
end
