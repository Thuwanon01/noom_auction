require "test_helper"

# Walks the whole seller journey through real requests (no shortcuts into the database), then the admin side.
class ProductOnboardingE2eTest < ActionDispatch::IntegrationTest
  INFO = { name: "Seiko 5 vintage watch", category: "watch", condition: "good",
           description: "Automatic Seiko 5 from 1978, runs well, new strap included.", brand: "Seiko", model: "5", year: 1978 }.freeze

  def window = { start_at: 3.hours.from_now.strftime("%Y-%m-%dT%H:%M"), stop_at: (3.hours.from_now + 2.days).strftime("%Y-%m-%dT%H:%M") }

  AUCTIONS = {
    "english" => { auction_type: "english", start_price: 1200, reserve_price: 2000, bid_increment: 50 },
    "dutch"   => { auction_type: "dutch", start_price: 5000, floor_price: 2000, price_drop: 250, drop_interval_minutes: 15 },
    "sealed"  => { auction_type: "sealed", start_price: 800 }
  }.freeze

  def json_upload(path, file) = post(path, params: { file: file }, headers: { "Accept" => "application/json" })

  def walk_to_step_4(auction_params, info: INFO)
    post products_path, params: { product: info }
    product = Product.order(:id).last
    follow_redirect!
    assert_select ".wizard-progress__count", "2/4"
    json_upload product_product_images_path(product), png_upload("cover.png")
    assert_response :created
    patch update_step_product_path(product, 2)
    follow_redirect!
    assert_select ".wizard-progress__count", "3/4"
    patch update_step_product_path(product, 3), params: { auction: auction_params.merge(window) }
    follow_redirect!
    assert_select ".wizard-progress__count", "4/4"
    product
  end

  setup { login_as users(:seller) }

  AUCTIONS.each do |type, params|
    test "seller lists a #{type} auction from step 1 to pending review" do
      product = walk_to_step_4(params)
      patch update_step_product_path(product, 4), params: { intent: "submit", product: { accept_terms: "1" } }
      assert_redirected_to my_products_path
      follow_redirect!
      assert_select ".flash--notice", /24 ชั่วโมง/
      assert_select "tr#product_#{product.id} .tag", "รอตรวจสอบ"

      product.reload
      assert_equal "pending_review", product.status
      assert_equal type, product.auction.auction_type
      assert_equal params[:start_price], product.auction.current_price
      assert_equal 1, product.product_images.count
    end
  end

  test "collectible journey needs proof before step 3" do
    post products_path, params: { product: INFO.merge(category: "collectible") }
    product = Product.order(:id).last
    json_upload product_product_images_path(product), png_upload
    patch update_step_product_path(product, 2)
    assert_response :unprocessable_entity
    json_upload product_product_documents_path(product), pdf_upload("certificate.pdf")
    patch update_step_product_path(product, 2)
    assert_redirected_to step_product_path(product, 3)
  end

  test "save as draft, leave, come back from the list and finish" do
    post products_path, params: { product: INFO }
    product = Product.order(:id).last
    get my_products_path
    assert_select "tr#product_#{product.id} .tag", "แบบร่าง"
    assert_select "tr#product_#{product.id} a[href=?]", step_product_path(product, 2)

    json_upload product_product_images_path(product), png_upload
    patch update_step_product_path(product, 2)
    patch update_step_product_path(product, 3), params: { auction: AUCTIONS["sealed"].merge(window) }
    patch update_step_product_path(product, 4), params: { intent: "draft" }
    assert_redirected_to my_products_path
    assert product.reload.draft?

    get my_products_path
    assert_select "tr#product_#{product.id} a[href=?]", step_product_path(product, 4)
    patch update_step_product_path(product, 4), params: { intent: "submit", product: { accept_terms: "1" } }
    assert product.reload.pending_review?
  end

  test "admin rejects, seller edits and resubmits, admin approves" do
    product = walk_to_step_4(AUCTIONS["english"])
    patch update_step_product_path(product, 4), params: { intent: "submit", product: { accept_terms: "1" } }

    login_as users(:admin)
    get admin_products_path
    assert_select "tr#product_#{product.id}"
    patch reject_admin_product_path(product), params: { rejection_reason: "Please add a photo of the back" }

    login_as users(:seller)
    get my_products_path
    assert_select "tr#product_#{product.id}", text: /Please add a photo of the back/
    assert_select "tr#product_#{product.id} a", "แก้ไขและส่งอีกครั้ง"
    json_upload product_product_images_path(product), png_upload("back.png")
    patch update_step_product_path(product, 4), params: { intent: "submit", product: { accept_terms: "1" } }
    assert_equal "pending_review", product.reload.status
    assert_nil product.rejection_reason
    assert_equal 2, product.product_images.count

    login_as users(:admin)
    patch approve_admin_product_path(product)
    assert_equal "available", product.reload.status

    login_as users(:seller)
    get step_product_path(product, 1)
    assert_redirected_to my_products_path
  end

  test "an approved product can enter an event and is then locked" do
    product = walk_to_step_4(AUCTIONS["english"])
    patch update_step_product_path(product, 4), params: { intent: "submit", product: { accept_terms: "1" } }
    product.reload.approve!
    product.start_event!
    assert_not product.update(name: "Sneaky rename of listed item")
    assert_not product.destroy
    delete product_path(product)
    assert Product.exists?(product.id)
  end

  test "a seller who is not onboarded cannot walk the flow at all" do
    login_as users(:newbie)
    get new_product_path
    assert_redirected_to onboarding_step_path(1)
  end
end
