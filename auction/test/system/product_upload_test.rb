require "browser_system_test_case"

# Exercises the JavaScript of wizard step 2 and 3 in a real browser (needs Chrome).
class ProductUploadTest < BrowserSystemTestCase
  setup do
    browser_sign_in users(:seller)
    @product = Product.create!(seller: users(:seller), name: "Browser test item", category: "camera", condition: "good",
                               description: "A camera used for the browser tests, fine.")
  end

  test "choosing files uploads each one and shows them as photos" do
    visit step_product_path(@product, 2)
    dir = Rails.root.join("tmp/system_uploads"); FileUtils.mkdir_p(dir)
    paths = %w[one two].map { |n| dir.join("#{n}.png").tap { |f| File.binwrite(f, ActiveSupport::TestCase::PNG_BYTES) } }
    page.driver.browser.find_element(css: "input[data-url$='product_images']").send_keys(paths.join("\n"))
    assert_selector ".photos__item", count: 2, wait: 10
    assert_selector ".photos__item .tag", text: "รูปปก", count: 1
  end

  test "a file of the wrong type is rejected in the browser with a message" do
    visit step_product_path(@product, 2)
    dir = Rails.root.join("tmp/system_uploads"); FileUtils.mkdir_p(dir)
    bad = dir.join("notes.txt"); File.write(bad, "hello")
    page.driver.browser.find_element(css: "input[data-url$='product_images']").send_keys(bad.to_s)
    assert_selector ".uploads__msg", text: "ชนิดไฟล์ไม่รองรับ", wait: 5
    assert_equal 0, @product.product_images.count
  end

  test "choosing an auction type reveals its fields and updates the preview" do
    @product.product_images.create!(position: 1, file: png_upload)
    visit step_product_path(@product, 3)
    assert_no_selector "input[name='auction[floor_price]']", visible: :visible
    choose "ประมูลลดราคา (Dutch)"
    assert_selector "input[name='auction[floor_price]']", visible: :visible
    assert_no_selector "input[name='auction[bid_increment]']", visible: :visible
    fill_in "auction[start_price]", with: "4500"
    assert_selector "[data-auction-setup-target=previewPrice]", text: "4,500"
    assert_selector "[data-auction-setup-target=previewType]", text: "Dutch"
  end
end
