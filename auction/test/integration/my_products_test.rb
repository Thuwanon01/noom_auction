require "test_helper"

class MyProductsTest < ActionDispatch::IntegrationTest
  setup { login_as users(:seller) }

  def product(status, name = "List item #{status}")
    Product.create!(seller: users(:seller), name: name, category: "camera", condition: "good",
                    description: "Description long enough for the listing.", status: status)
  end

  test "guest is sent to login" do
    reset!
    get my_products_path
    assert_redirected_to login_path
  end

  test "empty state with a call to action" do
    users(:seller).products.each { |p| p.update_columns(status: "available") && p.destroy! }
    get my_products_path
    assert_select ".empty", /ยังไม่มีสินค้า/
    assert_select ".empty a[href=?]", new_product_path
  end

  test "shows only my own products with code and thai status labels" do
    mine = product("pending_review")
    theirs = Product.create!(seller: users(:buyer), name: "Not mine at all")
    get my_products_path
    assert_select "tr#product_#{mine.id} .tag", "รอตรวจสอบ"
    assert_select "tr#product_#{mine.id}", text: /#{mine.code}/
    assert_select "tr#product_#{theirs.id}", 0
  end

  test "draft offers continue and delete" do
    d = product("draft")
    get my_products_path
    assert_select "tr#product_#{d.id} a", "แก้ไขต่อ"
    assert_select "tr#product_#{d.id} button", "ลบ"
  end

  test "continue link goes to the first incomplete step" do
    d = product("draft")
    get my_products_path
    assert_select "tr#product_#{d.id} a[href=?]", step_product_path(d, 2)
  end

  test "rejected shows the reason and a resubmit link" do
    r = product("rejected")
    r.update_columns(rejection_reason: "blurry photos")
    get my_products_path
    assert_select "tr#product_#{r.id}", text: /blurry photos/
    assert_select "tr#product_#{r.id} a", "แก้ไขและส่งอีกครั้ง"
  end

  test "pending, available, in_event, sold and withdrawn have no edit or delete actions" do
    %w[pending_review available in_event sold withdrawn].each do |status|
      p = product(status, "No actions for #{status}")
      get my_products_path
      assert_select "tr#product_#{p.id} a", 0, status
      assert_select "tr#product_#{p.id} button", 0, status
    end
  end

  test "deleting a draft removes it with its files and auction" do
    d = product("draft")
    d.product_images.create!(position: 1, file: png_upload)
    assert_difference [ "Product.count", "ProductImage.count" ], -1 do
      delete product_path(d)
    end
    assert_redirected_to my_products_path
  end

  test "only drafts can be deleted" do
    %w[pending_review rejected available in_event sold].each do |status|
      p = product(status, "Keep me #{status}")
      assert_no_difference("Product.count") { delete product_path(p) }
      assert_redirected_to my_products_path
    end
  end

  test "cannot delete someone else's draft" do
    other = Product.create!(seller: users(:buyer), name: "Buyer draft product")
    assert_no_difference("Product.count") { delete product_path(other) }
    assert_response :not_found
  end

  test "an in_event product cannot be opened for editing" do
    p = product("in_event")
    get step_product_path(p, 1)
    assert_redirected_to my_products_path
  end

  test "rejected product can be edited and resubmitted end to end" do
    p = product("rejected")
    p.update_columns(rejection_reason: "needs better photos")
    p.product_images.create!(position: 1, file: png_upload)
    start = 3.hours.from_now
    p.create_auction!(auction_type: "sealed", start_price: 500, current_price: 500, start_at: start, stop_at: start + 1.day)
    patch update_step_product_path(p, 1), params: { product: { name: "Renamed after rejection" } }
    assert_redirected_to step_product_path(p, 2)
    patch update_step_product_path(p, 4), params: { intent: "submit", product: { accept_terms: "1" } }
    assert_equal "pending_review", p.reload.status
    assert_equal "Renamed after rejection", p.name
    assert_nil p.rejection_reason
  end
end
