require "test_helper"

# M4.4 (#40): placing an English bid from the detail page.
class BidsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @auction = auctions(:english) # current 1,000, increment 100 -> minimum 1,100
    @buyer = users(:buyer)
  end

  def post_bid(amount:, key: SecureRandom.uuid, expected_price: @auction.current_price)
    post auction_bids_path(@auction), params: { amount: amount, idempotency_key: key, expected_price: expected_price }
  end

  test "the detail page shows the bid form with quick buttons and a fresh idempotency key" do
    sign_in_as @buyer
    get auction_path(@auction)
    assert_select "form.bid-box__form[action=?][data-controller=bid-form]", auction_bids_path(@auction) do
      assert_select "input[name=amount][min='1100'][step='1']"
      assert_select "input[type=hidden][name=idempotency_key][value]"
      assert_select "input[type=hidden][name=expected_price][value='1000']"
      assert_select "button.quick-bid", 3
      assert_select "button.quick-bid[data-bid-form-amount-param='1100']", text: "฿1,100"
      assert_select "button.quick-bid[data-bid-form-amount-param='1200']", text: "฿1,200"
      assert_select "button.quick-bid[data-bid-form-amount-param='1500']", text: "฿1,500"
      assert_select "button[type=submit]:not([disabled])"
      assert_select "dialog.confirm-dialog"
    end
  end

  test "the confirm dialog text includes the product name" do
    sign_in_as @buyer
    get auction_path(@auction)
    assert_select "form[data-bid-form-title-value=?]", "Vintage Film Camera"
  end

  test "guests are sent to log in" do
    post_bid(amount: 1_100)
    assert_redirected_to login_path
    assert_equal 0, @auction.bids.count
  end

  test "a valid bid redirects back and says you are the highest bidder" do
    sign_in_as @buyer
    post_bid(amount: 1_100)
    assert_redirected_to auction_path(@auction)
    follow_redirect!
    assert_select ".bid-flash--success", text: "You are the highest bidder"
    assert_select ".table tbody tr", 1
    assert_select "[data-testid=current-price]", text: "฿1,100"
  end

  test "below the minimum re-renders with the spec message and keeps the amount" do
    sign_in_as @buyer
    post_bid(amount: 1_050)
    assert_response :unprocessable_entity
    assert_select ".bid-flash--error", text: "The minimum bid is ฿1,100"
    assert_select "input[name=amount][value='1050']"
  end

  test "not a valid amount" do
    sign_in_as @buyer
    post_bid(amount: "abc")
    assert_select ".bid-flash--error", text: "Enter a valid amount"
  end

  test "price changed refreshes the price box and the minimum" do
    place = PlaceBid.call(user: users(:other_buyer), auction: @auction, amount: 1_500, idempotency_key: "x")
    assert place.success?
    sign_in_as @buyer
    post_bid(amount: 1_100, expected_price: 1_000)
    assert_response :unprocessable_entity
    assert_select ".bid-flash--error", text: "Price changed. The new minimum is ฿1,600"
    assert_select "[data-testid=current-price]", text: "฿1,500"
    assert_select "input[name=expected_price][value='1500']"
    assert_select "input[name=amount][min='1600']"
  end

  test "auction just ended" do
    sign_in_as @buyer
    @auction.update_columns(stop_at: 1.second.ago)
    post_bid(amount: 1_100)
    assert_select ".bid-flash--error", text: "This auction has just ended"
  end

  test "submitting the same key twice creates one bid" do
    sign_in_as @buyer
    post_bid(amount: 1_100, key: "same")
    post_bid(amount: 1_100, key: "same")
    assert_redirected_to auction_path(@auction)
    assert_equal 1, @auction.bids.count
  end

  test "over the bid limit shows the real limit" do
    @buyer.update!(credit_grade: "D")
    sign_in_as @buyer
    post_bid(amount: 10_100)
    assert_select ".bid-flash--error", text: "Over your bid limit. Your limit is ฿10,000"
  end

  test "the result is shown next to the form, not again as a page toast" do
    sign_in_as @buyer
    post_bid(amount: 1_100)
    follow_redirect!
    assert_select ".bid-flash--success", 1
    assert_select ".flash", text: "You are the highest bidder", count: 0
  end

  test "the highest bidder sees a note instead of the form" do
    sign_in_as @buyer
    post_bid(amount: 1_100)
    get auction_path(@auction)
    assert_select ".action-area[data-state=highest_bidder]"
    assert_select "form.bid-box__form", 0
  end
end
