require "test_helper"

class ProductFileTest < ActiveSupport::TestCase
  def draft = Product.create!(seller: users(:seller), name: "File test product")

  test "a png photo is accepted" do
    image = draft.product_images.new(position: 1, file: png_upload)
    assert image.valid?, image.errors.full_messages.to_sentence
  end

  test "an image without a file is rejected" do
    assert_not draft.product_images.new(position: 1).valid?
  end

  test "a text file renamed to .png is rejected because the bytes are checked, not the name" do
    fake = upload("just some text", "image/png", "fake.png")
    image = draft.product_images.new(position: 1, file: fake)
    assert_not image.valid?
    assert_includes image.errors[:file].join, "JPG or PNG"
  end

  test "a pdf is not accepted as a photo" do
    assert_not draft.product_images.new(position: 1, file: pdf_upload).valid?
  end

  test "photos over 5 MB are rejected" do
    assert_not draft.product_images.new(position: 1, file: png_upload(padding: 5.megabytes)).valid?
  end

  test "the 9th photo is rejected" do
    product = draft
    8.times { |i| product.product_images.create!(position: i + 1, file: png_upload("p#{i}.png")) }
    ninth = product.product_images.new(position: 9, file: png_upload("p9.png"))
    assert_not ninth.valid?
    assert_includes ninth.errors.full_messages.join, "at most 8"
  end

  test "proof accepts pdf and png but not text, and has a 10 MB limit" do
    product = draft
    assert product.product_documents.new(file: pdf_upload).valid?
    assert product.product_documents.new(file: png_upload).valid?
    assert_not product.product_documents.new(file: upload("text", "application/pdf", "x.pdf")).valid?
    assert_not product.product_documents.new(file: upload(PDF_BYTES, "application/pdf", "big.pdf", padding: 10.megabytes)).valid?
  end

  test "step 2 needs a photo, and proof for collectibles and vehicles" do
    product = Product.create!(seller: users(:seller), name: "Collectible thing", category: "collectible")
    assert_not product.valid?(:step2)
    product.product_images.create!(position: 1, file: png_upload)
    product = Product.find(product.id)
    assert_not product.valid?(:step2), "collectible still needs proof"
    assert_includes product.errors.full_messages.join, "Proof"
    product.product_documents.create!(file: pdf_upload)
    assert Product.find(product.id).valid?(:step2)
  end

  test "step 2 does not need proof for other categories" do
    product = Product.create!(seller: users(:seller), name: "Plain camera", category: "camera")
    product.product_images.create!(position: 1, file: png_upload)
    assert Product.find(product.id).valid?(:step2)
  end
end
