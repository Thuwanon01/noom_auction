require "test_helper"

class ProductTest < ActiveSupport::TestCase
  test "enums cover the spec values" do
    assert_equal 10, Product.categories.size
    assert_equal %w[new like_new good fair for_parts], Product.conditions.keys
    assert_equal %w[draft pending_review rejected available in_event sold withdrawn], Product.statuses.keys
  end

  test "new products start as draft" do
    assert Product.new.draft?
  end

  test "code must be unique" do
    dup = Product.new(code: products(:camera).code, name: "x", seller: users(:seller))
    assert_not dup.valid?
  end

  test "proof is required only for collectibles and vehicles" do
    assert Product.new(category: "collectible").proof_required?
    assert Product.new(category: "vehicle").proof_required?
    assert_not Product.new(category: "camera").proof_required?
  end

  test "product has images ordered by position and a document" do
    p = products(:camera)
    p.product_images.create!(position: 2)
    p.product_images.create!(position: 1)
    assert_equal [ 1, 2 ], p.product_images.map(&:position)
    assert p.product_documents.create!.proof?
  end

  test "destroying a product removes its auction and files" do
    p = products(:camera)
    p.update_columns(status: "available") # in_event products cannot be destroyed (M2.2)
    p.product_images.create!(position: 1)
    assert_difference [ "Auction.count", "ProductImage.count" ], -1 do
      p.destroy!
    end
  end

  test "a product has at most one auction" do
    assert_raises(ActiveRecord::RecordNotUnique) do
      Auction.create!(product: products(:camera), auction_type: "english", start_price: 100, current_price: 100,
                      start_at: 1.hour.from_now, stop_at: 2.hours.from_now)
    end
  end
end
