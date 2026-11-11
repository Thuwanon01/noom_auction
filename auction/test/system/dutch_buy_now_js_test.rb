require "application_system_test_case"

# M4.7 (#43) JavaScript: confirm dialog with the price, and the dialog opens
# again with the new price after a drop.
class DutchBuyNowJsTest < JsSystemTestCase
  setup do
    @auction = auctions(:dutch)
    @auction.update_columns(start_at: 25.minutes.ago) # 9,000
    sign_in_as users(:buyer)
    visit auction_path(@auction)
  end

  test "confirm dialog shows the price and buys" do
    click_button "Buy now at ฿9,000"
    within("dialog.confirm-dialog[open]") do
      assert_text "Buy now at ฿9,000?"
      click_button "Confirm"
    end
    assert_selector ".bid-flash--success", text: "You bought this item for ฿9,000"
    assert @auction.reload.sold?
  end

  test "price dropped after the page loaded: new price shown and asked again" do
    @auction.update_columns(start_at: 35.minutes.ago) # server price now 8,500
    click_button "Buy now at ฿9,000"
    within("dialog.confirm-dialog[open]") { click_button "Confirm" }

    assert_selector ".bid-flash--error", text: "Price changed. The new price is ฿8,500"
    within("dialog.confirm-dialog[open]") do
      assert_text "The price is now ฿8,500. Buy now?"
      click_button "Confirm"
    end
    assert_selector ".bid-flash--success", text: "You bought this item for ฿8,500"
  end
end
