require "test_helper"

class ProductWizardStep4Test < ActionDispatch::IntegrationTest
  setup do
    login_as users(:seller)
    @product = Product.create!(seller: users(:seller), name: "Ready to submit", category: "camera", condition: "good",
                               description: "A complete camera listing ready for review.", brand: "Canon")
    @product.product_images.create!(position: 1, file: png_upload)
    start = 3.hours.from_now
    @product.create_auction!(auction_type: "english", start_price: 1500, current_price: 1500, bid_increment: 50,
                             start_at: start, stop_at: start + 2.days)
  end

  def submit(terms: "1") = patch(update_step_product_path(@product, 4), params: { intent: "submit", product: { accept_terms: terms } })

  test "summary shows every step with edit links" do
    get step_product_path(@product, 4)
    assert_response :success
    assert_select ".wizard-progress__count", "4/4"
    assert_select ".facts", text: /Ready to submit/
    assert_select ".facts", text: /฿1,500/
    assert_select "a.review__edit", 3
    assert_select "a.review__edit[href=?]", step_product_path(@product, 1)
    assert_select "button[name=intent][value=submit]"
    assert_select "button[name=intent][value=draft]"
  end

  test "submit sends the product for review" do
    submit
    assert_redirected_to my_products_path
    assert_equal "pending_review", @product.reload.status
    follow_redirect!
    assert_select ".flash--notice", /24 ชั่วโมง/
  end

  test "submit without accepting the terms is refused" do
    submit(terms: "0")
    assert_response :unprocessable_entity
    assert_select ".form-errors", /seller terms/
    assert @product.reload.draft?
    patch update_step_product_path(@product, 4), params: { intent: "submit" }
    assert_response :unprocessable_entity
  end

  test "submit re-validates every step even when the url is hit directly" do
    @product.product_images.destroy_all
    submit
    assert_response :unprocessable_entity
    assert_select ".form-errors", /at least 1 photo/
    assert @product.reload.draft?
  end

  test "a collectible without proof cannot be submitted" do
    @product.update!(category: "collectible")
    submit
    assert_response :unprocessable_entity
    assert_select ".form-errors", /Proof/
  end

  test "an auction whose start time has already passed cannot be submitted" do
    @product.auction.update_columns(start_at: 10.minutes.ago)
    submit
    assert_response :unprocessable_entity
    assert_select ".form-errors", /out of date/
    assert @product.reload.draft?
  end

  test "an invalid product field (description too short) blocks submit" do
    @product.update_columns(description: "too short")
    submit
    assert_response :unprocessable_entity
  end

  test "save as draft keeps the draft and returns to the list without needing the terms" do
    patch update_step_product_path(@product, 4), params: { intent: "draft" }
    assert_redirected_to my_products_path
    assert @product.reload.draft?
  end

  test "rejected product shows the reason and can be resubmitted" do
    @product.update_columns(status: "rejected", rejection_reason: "photos too dark")
    get step_product_path(@product, 4)
    assert_select ".flash--alert", /photos too dark/
    submit
    assert_equal "pending_review", @product.reload.status
    assert_nil @product.rejection_reason
  end

  test "a product already under review cannot be submitted again or edited" do
    submit
    submit
    assert_redirected_to my_products_path
    assert_equal "pending_review", @product.reload.status
  end

  test "another seller cannot submit this product" do
    login_as users(:buyer)
    submit
    assert_response :not_found
    assert @product.reload.draft?
  end
end
