require "test_helper"

# M4.8 (#44) UI: sealed bid form, revise, and no amount leaks before close.
class SealedBidsControllerTest < ActionDispatch::IntegrationTest
  include CatalogFactory

  SECRET = 7_654_321

  setup do
    @auction = auctions(:sealed) # start 2,000
    @buyer = users(:buyer)
    place_bid(@auction, users(:other_buyer), SECRET)
    sign_in_as @buyer
  end

  def submit(amount, key: SecureRandom.uuid)
    post auction_bids_path(@auction), params: { amount: amount, idempotency_key: key }
  end

  def assert_no_secret
    assert_no_match "7,654,321", response.body
    assert_no_match SECRET.to_s, response.body
  end

  test "the detail page shows a sealed form: one amount, no quick buttons, sealed confirm text" do
    get auction_path(@auction)
    assert_select "form.bid-box__form[data-controller=bid-form]" do
      assert_select "input[name=amount][min='2000']"
      assert_select "button.quick-bid", 0
      assert_select "input[name=expected_price]", 0
      assert_select "button[type=submit]", text: "ยื่นซอง"
    end
    assert_select "form[data-bid-form-confirm-value=?]", "Submit a sealed bid of %{amount}?"
    assert_no_secret
  end

  test "submitting a sealed bid" do
    submit(2_500)
    assert_redirected_to auction_path(@auction)
    follow_redirect!
    assert_select ".bid-flash--success", text: "Your sealed bid of ฿2,500 was submitted"
    assert_select "[data-testid=my-sealed-bid]", text: "฿2,500"
    assert_select "button[type=submit]", text: "แก้ไขราคา"
    assert_select "[data-testid=bid-count]", text: "2"
    assert_no_secret
  end

  test "revising replaces the amount" do
    submit(2_500)
    submit(3_000)
    follow_redirect!
    assert_select ".bid-flash--success", text: "Your sealed bid was changed to ฿3,000"
    assert_select "[data-testid=my-sealed-bid]", text: "฿3,000"
    assert_equal 1, @auction.bids.where(user: @buyer).count
    assert_no_secret
  end

  test "below the starting price" do
    submit(1_999)
    assert_response :unprocessable_entity
    assert_select ".bid-flash--error", text: "The minimum bid is ฿2,000"
    assert_no_secret
  end

  test "the bid history table stays hidden before close" do
    submit(2_500)
    follow_redirect!
    assert_select ".table", 0
  end

  test "everything is revealed after stop_at" do
    submit(2_500)
    @auction.update_columns(stop_at: 1.second.ago)
    get auction_path(@auction)
    assert_select ".table td", text: "฿7,654,321"
    assert_select ".table td", text: "฿2,500"
  end
end
