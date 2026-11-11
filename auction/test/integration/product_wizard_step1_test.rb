require "test_helper"

class ProductWizardStep1Test < ActionDispatch::IntegrationTest
  VALID = { name: "Canon AE-1 film camera", category: "camera", condition: "good",
            description: "Working Canon AE-1 with 50mm lens, light meter works fine.",
            brand: "Canon", model: "AE-1", year: 1979 }.freeze

  setup { login_as users(:seller) }

  test "guest is sent to login" do
    reset!
    get new_product_path
    assert_redirected_to login_path
  end

  test "a user who has not finished onboarding cannot start" do
    login_as users(:newbie)
    get new_product_path
    assert_redirected_to onboarding_step_path(1)
    assert_no_difference("Product.count") { post products_path, params: { product: VALID } }
  end

  test "step 1 form renders with the progress bar" do
    get new_product_path
    assert_response :success
    assert_select ".wizard-progress__count", "1/4"
    assert_select "input[name='product[name]']"
  end

  test "valid step 1 creates a draft owned by the user and moves to step 2" do
    assert_difference("Product.count", 1) { post products_path, params: { product: VALID } }
    product = Product.order(:id).last
    assert product.draft?
    assert_equal users(:seller), product.seller
    assert_match(/\AP-\d{4}\z/, product.code)
    assert_redirected_to step_product_path(product, 2)
  end

  test "invalid step 1 shows errors and saves nothing" do
    assert_no_difference("Product.count") do
      post products_path, params: { product: VALID.merge(name: "abc", description: "short", category: "") }
    end
    assert_response :unprocessable_entity
    assert_select ".form-errors li", minimum: 3
  end

  test "seller cannot be forged through params" do
    post products_path, params: { product: VALID.merge(seller_id: users(:buyer).id, status: "available", code: "P-9999") }
    product = Product.order(:id).last
    assert_equal users(:seller), product.seller
    assert product.draft?
    assert_not_equal "P-9999", product.code
  end

  test "editing step 1 again keeps data and resumes" do
    post products_path, params: { product: VALID }
    product = Product.order(:id).last
    get step_product_path(product, 1)
    assert_select "input[name='product[name]'][value='#{VALID[:name]}']"
    patch update_step_product_path(product, 1), params: { product: { name: "Canon AE-1 Program" } }
    assert_equal "Canon AE-1 Program", product.reload.name
    assert_equal "Canon", product.brand
  end

  test "cannot jump ahead of saved data" do
    post products_path, params: { product: VALID }
    product = Product.order(:id).last
    get step_product_path(product, 4)
    assert_redirected_to step_product_path(product, 2)
  end

  test "other sellers products are not reachable" do
    login_as users(:buyer)
    get step_product_path(products(:camera), 1)
    assert_response :not_found
  end

  test "non-editable status is refused" do
    post products_path, params: { product: VALID }
    product = Product.order(:id).last
    product.update_columns(status: "pending_review")
    get step_product_path(product, 1)
    assert_redirected_to my_products_path
  end

  test "step outside 1-4 is not routable" do
    post products_path, params: { product: VALID }
    product = Product.order(:id).last
    get "/products/#{product.id}/steps/9"
    assert_response :not_found
  end
end
