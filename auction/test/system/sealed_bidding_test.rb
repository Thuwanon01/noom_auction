require "application_system_test_case"

# M4.8 (#44) acceptance: submit then revise a sealed bid.
class SealedBiddingTest < ApplicationSystemTestCase
  test "submit and revise a sealed bid" do
    auction = auctions(:sealed)
    sign_in_as users(:buyer)
    visit auction_path(auction)

    fill_in "amount", with: "2500"
    click_button "ยื่นซอง"
    assert_selector ".bid-flash--success", text: "Your sealed bid of ฿2,500 was submitted"

    fill_in "amount", with: "3100"
    click_button "แก้ไขราคา"
    assert_selector ".bid-flash--success", text: "Your sealed bid was changed to ฿3,100"
    assert_selector "[data-testid=my-sealed-bid]", text: "฿3,100"
  end
end
