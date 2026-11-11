require "test_helper"

class ProductWizardStep3Test < ActionDispatch::IntegrationTest
  setup do
    login_as users(:seller)
    @product = Product.create!(seller: users(:seller), name: "Step three product", category: "camera",
                               condition: "good", description: "A camera used for the step three tests.")
    @product.product_images.create!(position: 1, file: png_upload)
  end

  def params(**over)
    start = 3.hours.from_now
    { auction: { auction_type: "english", start_price: 1500, reserve_price: 3000, bid_increment: 50,
                 start_at: start.strftime("%Y-%m-%dT%H:%M"), stop_at: (start + 2.days).strftime("%Y-%m-%dT%H:%M") }.merge(over) }
  end

  test "step 3 is not reachable before a photo exists" do
    @product.product_images.destroy_all
    get step_product_path(@product, 3)
    assert_redirected_to step_product_path(@product, 2)
  end

  test "form shows the three types with explainers and the preview" do
    get step_product_path(@product, 3)
    assert_response :success
    assert_select "input[name='auction[auction_type]']", 3
    assert_select ".type-option .field__hint", 3
    assert_select ".preview"
    assert_select ".wizard-progress__count", "3/4"
  end

  test "valid english setup is saved and moves to step 4" do
    assert_difference("Auction.count", 1) { patch update_step_product_path(@product, 3), params: params }
    a = @product.reload.auction
    assert_equal "english", a.auction_type
    assert_equal 1500, a.current_price
    assert_equal 50, a.bid_increment
    assert_redirected_to step_product_path(@product, 4)
  end

  test "dutch setup keeps floor, drop and interval" do
    patch update_step_product_path(@product, 3),
          params: params(auction_type: "dutch", floor_price: 500, price_drop: 100, drop_interval_minutes: 5)
    a = @product.reload.auction
    assert_equal [ 500, 100, 5 ], [ a.floor_price, a.price_drop, a.drop_interval_minutes ]
  end

  test "sealed setup ignores dutch fields sent by a tampered form" do
    patch update_step_product_path(@product, 3),
          params: params(auction_type: "sealed", floor_price: 5, price_drop: 5, drop_interval_minutes: 5)
    a = @product.reload.auction
    assert_nil a.floor_price
  end

  test "invalid setup shows errors, keeps the input and saves nothing" do
    assert_no_difference("Auction.count") do
      patch update_step_product_path(@product, 3), params: params(start_price: 50, start_at: 10.minutes.from_now.strftime("%Y-%m-%dT%H:%M"))
    end
    assert_response :unprocessable_entity
    assert_select ".form-errors li", minimum: 2
    assert_select "input[name='auction[start_price]'][value='50']"
  end

  test "saving again updates the same auction instead of duplicating it" do
    patch update_step_product_path(@product, 3), params: params
    assert_no_difference("Auction.count") do
      patch update_step_product_path(@product, 3), params: params(start_price: 2000, reserve_price: nil)
    end
    assert_equal 2000, @product.reload.auction.start_price
    assert_nil @product.auction.reserve_price
  end

  test "unknown params such as status or winner cannot be set" do
    patch update_step_product_path(@product, 3), params: params(status: "sold", winner_id: users(:buyer).id, current_price: 1)
    a = @product.reload.auction
    assert a.open?
    assert_nil a.winner_id
    assert_equal 1500, a.current_price
  end

  test "step 4 needs a saved, still valid auction" do
    get step_product_path(@product, 4)
    assert_redirected_to step_product_path(@product, 3)
    patch update_step_product_path(@product, 3), params: params
    @product.auction.update_columns(start_at: 1.hour.ago, stop_at: 1.day.from_now)
    get step_product_path(@product, 4)
    assert_redirected_to step_product_path(@product, 3)
  end
end
