require "application_system_test_case"

# M4.4 (#40) JavaScript behaviour: quick buttons, client-side checks and the
# confirm dialog. Needs Chrome; skipped where it is not installed (CI/WSL).
class EnglishBiddingJsTest < ApplicationSystemTestCase
  driven_by :selenium, using: :headless_chrome, screen_size: [ 1280, 900 ]

  setup do
    skip "Chrome not available" unless system("which google-chrome chromium > /dev/null 2>&1") || File.exist?("/Applications/Google Chrome.app")
    @auction = auctions(:english)
    visit login_path
    fill_in "email", with: users(:buyer).email
    fill_in "password", with: "password123"
    click_button "Login"
    assert_no_current_path login_path
    visit auction_path(@auction)
  end

  test "quick button fills, confirm dialog shows the text, confirm places the bid" do
    click_button "฿1,200"
    assert_equal "1200", find_field("amount").value

    click_button "เสนอราคา"
    within("dialog.confirm-dialog[open]") do
      assert_text "Bid ฿1,200 on Vintage Film Camera? A bid cannot be withdrawn."
      click_button "Confirm"
    end

    assert_selector ".bid-flash--success", text: "You are the highest bidder"
    assert_equal 1, @auction.bids.count
  end

  test "cancel closes the dialog and places nothing" do
    click_button "฿1,100"
    click_button "เสนอราคา"
    within("dialog.confirm-dialog[open]") { click_button "Cancel" }
    assert_no_selector "dialog.confirm-dialog[open]"
    assert_equal 0, @auction.bids.count
  end

  test "below the minimum is caught before the dialog" do
    fill_in "amount", with: "1050"
    click_button "เสนอราคา"
    assert_selector ".bid-flash--error", text: "The minimum bid is ฿1,100"
    assert_no_selector "dialog.confirm-dialog[open]"
  end
end
