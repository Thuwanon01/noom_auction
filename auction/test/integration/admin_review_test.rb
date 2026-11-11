require "test_helper"

class AdminReviewTest < ActionDispatch::IntegrationTest
  setup do
    @product = Product.create!(seller: users(:seller), name: "Waiting for review", category: "camera", condition: "good",
                               description: "A complete camera listing waiting for the admin.", status: "pending_review")
    @product.product_images.create!(position: 1, file: png_upload)
  end

  test "guest is sent to login" do
    get admin_products_path
    assert_redirected_to login_path
  end

  test "a normal user gets 403 on every admin action" do
    login_as users(:seller)
    get admin_products_path
    assert_response :forbidden
    get admin_product_path(@product)
    assert_response :forbidden
    patch approve_admin_product_path(@product)
    assert_response :forbidden
    patch reject_admin_product_path(@product), params: { rejection_reason: "x" }
    assert_response :forbidden
    assert @product.reload.pending_review?
  end

  test "queue lists only pending products, oldest first" do
    older = Product.create!(seller: users(:seller), name: "Older submission", status: "pending_review")
    older.update_columns(updated_at: 2.days.ago)
    Product.create!(seller: users(:seller), name: "Still a draft item")
    login_as users(:admin)
    get admin_products_path
    assert_response :success
    names = css_select("tbody tr td:nth-child(2)").map(&:text)
    assert_includes names, "Waiting for review"
    assert_not_includes names, "Still a draft item"
    assert_operator names.index("Older submission"), :<, names.index("Waiting for review")
  end

  test "detail shows photos, proof and the decision forms" do
    @product.product_documents.create!(file: pdf_upload("receipt.pdf"))
    login_as users(:admin)
    get admin_product_path(@product)
    assert_response :success
    assert_select ".photos__img", 1
    assert_select ".docs a", "receipt.pdf"
    assert_select "form[action=?]", approve_admin_product_path(@product)
    assert_select "textarea[name=rejection_reason]"
  end

  test "approve makes the product available" do
    login_as users(:admin)
    patch approve_admin_product_path(@product)
    assert_redirected_to admin_products_path
    assert_equal "available", @product.reload.status
  end

  test "reject stores the reason and the seller sees it" do
    login_as users(:admin)
    patch reject_admin_product_path(@product), params: { rejection_reason: "  photos too dark  " }
    assert_equal "rejected", @product.reload.status
    assert_equal "photos too dark", @product.rejection_reason
    login_as users(:seller)
    get my_products_path
    assert_select "tr#product_#{@product.id}", text: /photos too dark/
  end

  test "reject without a reason is refused" do
    login_as users(:admin)
    patch reject_admin_product_path(@product), params: { rejection_reason: "   " }
    assert_response :unprocessable_entity
    assert_select ".form-errors", /เหตุผล/
    assert @product.reload.pending_review?
    assert_nil @product.rejection_reason
  end

  test "a product that was already decided cannot be decided again" do
    login_as users(:admin)
    patch approve_admin_product_path(@product)
    patch reject_admin_product_path(@product), params: { rejection_reason: "too late" }
    assert_redirected_to admin_products_path
    assert_equal "available", @product.reload.status
    patch approve_admin_product_path(@product)
    assert_equal "available", @product.reload.status
  end

  test "drafts cannot be approved by calling the endpoint directly" do
    draft = Product.create!(seller: users(:seller), name: "Not submitted yet")
    login_as users(:admin)
    patch approve_admin_product_path(draft)
    assert draft.reload.draft?
  end

  test "admin link only appears for admins" do
    login_as users(:seller)
    get my_products_path
    assert_select "a[href=?]", admin_products_path, 0
    login_as users(:admin)
    get my_products_path
    assert_select "a[href=?]", admin_products_path
  end

  test "an approved product can be put into an event but not edited by the seller" do
    login_as users(:admin)
    patch approve_admin_product_path(@product)
    login_as users(:seller)
    get step_product_path(@product, 1)
    assert_redirected_to my_products_path
  end
end
