require "application_system_test_case"

# M4.8 (#44) JavaScript: sealed confirm text and the start-price check.
class SealedBiddingJsTest < JsSystemTestCase
  setup do
    @auction = auctions(:sealed)
    sign_in_as users(:buyer)
    visit auction_path(@auction)
  end

  test "confirm dialog says Submit a sealed bid of X?" do
    fill_in "amount", with: "2500"
    click_button "ยื่นซอง"
    within("dialog.confirm-dialog[open]") do
      assert_text "Submit a sealed bid of ฿2,500?"
      click_button "Confirm"
    end
    assert_selector ".bid-flash--success", text: "Your sealed bid of ฿2,500 was submitted"
  end

  test "below the starting price is caught before the dialog" do
    fill_in "amount", with: "1500"
    click_button "ยื่นซอง"
    assert_selector ".bid-flash--error", text: "The minimum bid is ฿2,000"
    assert_no_selector "dialog.confirm-dialog[open]"
  end
end
