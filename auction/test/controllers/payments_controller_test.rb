require "test_helper"

# M4.11 (#47) UI: the seller marks a won auction as paid.
class PaymentsControllerTest < ActionDispatch::IntegrationTest
  include CatalogFactory

  setup do
    @auction = auctions(:english)
    @auction.update_columns(stop_at: 1.minute.ago, reserve_price: nil)
    place_bid(@auction, users(:buyer), 1_500, at: 2.minutes.ago)
    CloseAuction.call(@auction)
    @auction.reload
  end

  test "the seller sees the payment deadline and a mark-as-paid button" do
    sign_in_as users(:seller)
    get auction_path(@auction)
    assert_select ".payment", text: /รอผู้ชนะชำระเงินภายใน/
    assert_select "form[action=?] button", auction_payment_path(@auction), text: "ยืนยันว่าได้รับชำระเงินแล้ว"
  end

  test "the winner sees their deadline, no button" do
    sign_in_as users(:buyer)
    get auction_path(@auction)
    assert_select ".payment", text: /คุณชนะการประมูล กรุณาชำระเงินภายใน/
    assert_select "form[action=?]", auction_payment_path(@auction), 0
  end

  test "other viewers see neither" do
    sign_in_as users(:other_buyer)
    get auction_path(@auction)
    assert_select ".payment", 0
  end

  test "the seller marks it paid" do
    sign_in_as users(:seller)
    post auction_payment_path(@auction)
    assert_redirected_to auction_path(@auction)
    follow_redirect!
    assert_select ".bid-flash--success", text: "Marked as paid"
    assert_select ".payment", text: /ชำระเงินแล้ว/
    assert_select "form[action=?]", auction_payment_path(@auction), 0
    assert @auction.reload.paid_at
  end

  test "someone else cannot mark it paid" do
    sign_in_as users(:buyer)
    post auction_payment_path(@auction)
    assert_redirected_to auction_path(@auction)
    assert_nil @auction.reload.paid_at
    follow_redirect!
    assert_select ".bid-flash--error", text: "Only the seller can mark this as paid"
  end

  test "after the window it cannot be marked paid" do
    travel_to @auction.payment_due_at + 1.minute do
      sign_in_as users(:seller)
      post auction_payment_path(@auction)
      follow_redirect!
      assert_select ".bid-flash--error", text: "The payment window has ended"
    end
  end

  test "guests are sent to log in" do
    post auction_payment_path(@auction)
    assert_redirected_to login_path
  end
end
