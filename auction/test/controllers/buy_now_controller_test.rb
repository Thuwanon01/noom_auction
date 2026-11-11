require "test_helper"

# M4.7 (#43): Dutch "Buy now" from the detail page.
class BuyNowControllerTest < ActionDispatch::IntegrationTest
  setup do
    @auction = auctions(:dutch) # 10,000 dropping 500 every 10 min to 5,000
    @auction.update_columns(start_at: 25.minutes.ago) # price now 9,000; next drop in ~5 min
    @buyer = users(:buyer)
  end

  def buy(expected_price:, key: SecureRandom.uuid)
    post auction_bids_path(@auction), params: { expected_price: expected_price, idempotency_key: key }
  end

  test "the detail page shows the live price, a drop countdown and one Buy now button" do
    sign_in_as @buyer
    get auction_path(@auction)
    assert_select "[data-testid=current-price]", text: "฿9,000"
    assert_select "[data-testid=next-drop][data-controller~=countdown]"
    assert_select "form.buy-now[data-controller=buy-now]" do
      assert_select "input[type=hidden][name=expected_price][value='9000']"
      assert_select "input[type=hidden][name=idempotency_key][value]"
      assert_select "button[type=submit]", text: "Buy now at ฿9,000"
      assert_select "dialog.confirm-dialog"
      assert_select "input[name=amount]", 0
    end
  end

  test "at the floor there is no drop countdown" do
    @auction.update_columns(start_at: 3.hours.ago)
    sign_in_as @buyer
    get auction_path(@auction)
    assert_select "[data-testid=current-price]", text: "฿5,000"
    assert_select "[data-testid=next-drop]", 0
  end

  test "buying at the current price wins and shows the result" do
    sign_in_as @buyer
    buy(expected_price: 9_000)
    assert_redirected_to auction_path(@auction)
    follow_redirect!
    assert_select ".bid-flash--success", text: "You bought this item for ฿9,000. Please pay within 48 hours"
    assert @auction.reload.sold?
  end

  test "a stale price shows the new price and asks again" do
    sign_in_as @buyer
    buy(expected_price: 9_500)
    assert_response :unprocessable_entity
    assert_select ".bid-flash--error", text: "Price changed. The new price is ฿9,000"
    assert_select "form.buy-now[data-buy-now-reconfirm-value=true]"
    assert_select "button[type=submit]", text: "Buy now at ฿9,000"
    assert @auction.reload.open?
  end

  test "another viewer sees Sold" do
    BuyNow.call(user: users(:other_buyer), auction: @auction, expected_price: 9_000, idempotency_key: "k")
    sign_in_as @buyer
    get auction_path(@auction)
    assert_select ".result", text: /Sold/
    assert_select "form.buy-now", 0
  end

  test "buying after someone else got it says Sold" do
    BuyNow.call(user: users(:other_buyer), auction: @auction, expected_price: 9_000, idempotency_key: "k")
    sign_in_as @buyer
    buy(expected_price: 9_000)
    assert_select ".bid-flash--error", text: "Sold"
  end
end
