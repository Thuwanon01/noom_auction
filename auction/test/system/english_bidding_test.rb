require "application_system_test_case"

# M4.4 (#40) acceptance: place a bid and see it in the history; a double
# submit (same idempotency key) creates one bid. rack_test does not run JS,
# so the confirm dialog is skipped and the form posts directly.
class EnglishBiddingTest < ApplicationSystemTestCase
  setup do
    @auction = auctions(:english)
    sign_in_as users(:buyer)
  end

  test "place a bid and see it in the history" do
    visit auction_path(@auction)
    fill_in "amount", with: "1200"
    click_button "เสนอราคา"

    assert_selector ".bid-flash--success", text: "You are the highest bidder"
    within(".table tbody") { assert_selector "tr", count: 1, text: "฿1,200" }
    assert_selector "[data-testid=current-price]", text: "฿1,200"
  end

  test "submitting the same form twice creates one bid" do
    visit auction_path(@auction)
    key = find("input[name=idempotency_key]", visible: false).value
    fill_in "amount", with: "1100"
    click_button "เสนอราคา"
    page.driver.post auction_bids_path(@auction), amount: 1100, idempotency_key: key, expected_price: 1000

    assert_equal 1, @auction.bids.count
  end
end
