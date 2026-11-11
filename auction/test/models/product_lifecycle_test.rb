require "test_helper"

class ProductLifecycleTest < ActiveSupport::TestCase
  def build(status)
    Product.create!(seller: users(:seller), name: "Lifecycle #{status}", status: status)
  end

  test "every allowed transition works" do
    Product::TRANSITIONS.each do |from, targets|
      targets.each do |to|
        product = build(from)
        product.transition_to!(to, **(to == "rejected" ? { rejection_reason: "blurry" } : {}))
        assert_equal to, product.reload.status, "#{from} -> #{to}"
      end
    end
  end

  test "every other transition is refused" do
    Product::TRANSITIONS.each do |from, targets|
      (Product.statuses.keys - targets - [ from ]).each do |to|
        product = build(from)
        assert_raises(Product::InvalidTransition, "#{from} -> #{to}") { product.transition_to!(to) }
        assert_equal from, product.reload.status
      end
    end
  end

  test "named helpers follow the happy path" do
    p = build("draft")
    p.submit!; assert p.pending_review?
    p.approve!; assert p.available?
    p.start_event!; assert p.in_event?
    p.await_payment!; assert p.pending_payment?
    p.mark_sold!; assert p.sold?
  end

  test "reject needs a reason and resubmit clears it" do
    p = build("pending_review")
    assert_raises(ArgumentError) { p.reject!("") }
    p.reject!("photos too dark")
    assert_equal "photos too dark", p.rejection_reason
    p.submit!
    assert_nil p.rejection_reason
  end

  test "an in_event product cannot be edited or deleted" do
    p = build("in_event")
    assert_not p.update(name: "Changed name")
    assert_includes p.errors.full_messages.join, "in an event"
    assert_not p.destroy
    assert Product.exists?(p.id)
    assert p.reload.update(status: "sold"), "status itself may still change"
  end

  test "editable only while draft or rejected" do
    assert build("draft").editable?
    assert build("rejected").editable?
    assert_not build("pending_review").editable?
    assert_not build("available").editable?
  end

  test "code is generated as P-0001 style and increments" do
    Bid.delete_all; Auction.delete_all; Product.delete_all
    a = Product.create!(seller: users(:seller), name: "First")
    b = Product.create!(seller: users(:seller), name: "Second")
    assert_equal "P-0001", a.code
    assert_equal "P-0002", b.code
    assert_equal "P-0003", Product.next_code
  end

  test "next code ignores gaps and sorts numerically past 9999" do
    Bid.delete_all; Auction.delete_all; Product.delete_all
    Product.create!(seller: users(:seller), name: "Old", code: "P-9999")
    assert_equal "P-10000", Product.next_code
  end

  test "an insert that loses the race for a code is retried with a fresh one" do
    Bid.delete_all; Auction.delete_all; Product.delete_all
    Product.create!(seller: users(:seller), name: "Existing") # P-0001
    stale = Product.new(seller: users(:seller), name: "Racer", code: "P-0001")
    stale.instance_variable_set(:@generated_code, true)
    stale.save!(validate: false) # validation would have passed too in a real race
    assert_equal "P-0002", stale.code
    assert_equal 2, Product.distinct.count(:code)
  end

  test "a code the seller typed is never silently replaced" do
    Product.create!(seller: users(:seller), name: "Existing", code: "P-7777")
    dup = Product.new(seller: users(:seller), name: "Dup", code: "P-7777")
    assert_raises(ActiveRecord::RecordNotUnique) { dup.save!(validate: false) }
  end

  test "thai labels exist for every status and category" do
    assert_equal Product.statuses.keys.sort, Product::STATUS_LABELS.keys.sort
    assert_equal Product.categories.keys.sort, Product::CATEGORY_LABELS.keys.sort
    assert_equal "รอตรวจสอบ", build("pending_review").status_label
  end
end
