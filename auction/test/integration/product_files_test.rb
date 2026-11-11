require "test_helper"

class ProductFilesTest < ActionDispatch::IntegrationTest
  setup do
    login_as users(:seller)
    @product = Product.create!(seller: users(:seller), name: "Upload product", category: "camera",
                               condition: "good", description: "A camera used for the upload tests, fine.")
  end

  def json_post(path, file)
    post path, params: { file: file }, headers: { "Accept" => "application/json" }
  end

  test "uploading a photo returns 201 and appends it in order" do
    json_post product_product_images_path(@product), png_upload("a.png")
    assert_response :created
    json_post product_product_images_path(@product), png_upload("b.png")
    assert_equal [ 1, 2 ], @product.product_images.pluck(:position)
    assert_equal "a.png", @product.product_images.first.file.filename.to_s
  end

  test "a bad file returns 422 with a message and stores nothing" do
    assert_no_difference("ProductImage.count") do
      json_post product_product_images_path(@product), upload("hello", "image/png", "x.png")
    end
    assert_response :unprocessable_entity
    assert_match(/JPG or PNG/, response.parsed_body["errors"].join)
  end

  test "one failed file does not affect the others" do
    json_post product_product_images_path(@product), png_upload("ok.png")
    json_post product_product_images_path(@product), upload("hello", "image/png", "bad.png")
    json_post product_product_images_path(@product), png_upload("ok2.png")
    assert_equal 2, @product.product_images.count
  end

  test "ninth photo is refused" do
    8.times { |i| json_post product_product_images_path(@product), png_upload("p#{i}.png") }
    json_post product_product_images_path(@product), png_upload("p9.png")
    assert_response :unprocessable_entity
    assert_equal 8, @product.product_images.count
  end

  test "reorder changes the cover" do
    3.times { |i| json_post product_product_images_path(@product), png_upload("p#{i}.png") }
    ids = @product.product_images.pluck(:id)
    patch reorder_product_product_images_path(@product), params: { ids: ids.reverse }
    assert_response :no_content
    assert_equal ids.reverse, @product.product_images.reload.pluck(:id)
  end

  test "reorder rejects ids that are not exactly this product's images" do
    json_post product_product_images_path(@product), png_upload
    other = Product.create!(seller: users(:seller), name: "Another product")
    foreign = other.product_images.create!(position: 1, file: png_upload).id
    patch reorder_product_product_images_path(@product), params: { ids: [ foreign ] }
    assert_response :unprocessable_entity
  end

  test "deleting a photo closes the gap" do
    3.times { |i| json_post product_product_images_path(@product), png_upload("p#{i}.png") }
    delete product_product_image_path(@product, @product.product_images.second)
    assert_redirected_to step_product_path(@product, 2)
    assert_equal [ 1, 2 ], @product.product_images.reload.pluck(:position)
  end

  test "another seller cannot upload to or delete from this product" do
    json_post product_product_images_path(@product), png_upload
    login_as users(:buyer)
    json_post product_product_images_path(@product), png_upload("evil.png")
    assert_response :not_found
    delete product_product_image_path(@product, @product.product_images.first)
    assert_response :not_found
    assert_equal 1, @product.product_images.count
  end

  test "uploads are refused once the product is under review" do
    @product.update_columns(status: "pending_review")
    json_post product_product_images_path(@product), png_upload
    assert_response :forbidden
  end

  test "proof upload and delete" do
    json_post product_product_documents_path(@product), pdf_upload
    assert_response :created
    delete product_product_document_path(@product, @product.product_documents.first)
    assert_equal 0, @product.product_documents.count
  end

  test "step 2 page lists photos and marks the first as cover" do
    2.times { |i| json_post product_product_images_path(@product), png_upload("p#{i}.png") }
    get step_product_path(@product, 2)
    assert_response :success
    assert_select ".photos__item", 2
    assert_select ".photos__item .tag", text: "รูปปก", count: 1
    assert_select ".wizard-progress__count", "2/4"
  end

  test "step 2 hint says proof is required only for collectibles" do
    get step_product_path(@product, 2)
    assert_select ".field__label", text: /ไม่บังคับ/
    @product.update!(category: "collectible")
    get step_product_path(@product, 2)
    assert_select ".field__label", text: /เอกสารยืนยันความแท้ \*/
  end

  test "Next without a photo shows an error; with a photo it moves on" do
    patch update_step_product_path(@product, 2)
    assert_response :unprocessable_entity
    assert_select ".form-errors", /at least 1 photo/
    json_post product_product_images_path(@product), png_upload
    patch update_step_product_path(@product, 2)
    assert_redirected_to step_product_path(@product, 3)
  end

  test "collectible cannot pass step 2 without proof" do
    @product.update!(category: "collectible")
    json_post product_product_images_path(@product), png_upload
    patch update_step_product_path(@product, 2)
    assert_response :unprocessable_entity
    json_post product_product_documents_path(@product), pdf_upload
    patch update_step_product_path(@product, 2)
    assert_redirected_to step_product_path(@product, 3)
  end
end
