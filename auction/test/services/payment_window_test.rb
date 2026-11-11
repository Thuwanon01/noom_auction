require "test_helper"

class PaymentWindowTest < ActiveSupport::TestCase
  setup do
    @auction = auctions(:english)
    @closed_at = Time.current.change(usec: 0)
    @auction.update!(stop_at: @closed_at - 1.second)
    @auction.bids.create!(user: users(:buyer), amount: 1_500, idempotency_key: "w", placed_at: @closed_at - 1.minute)
    CloseAuction.call(@auction, now: @closed_at)
    @auction.reload
  end

  test "winning sets payment_due_at to closed_at + 48 hours" do
    assert_equal @closed_at + 48.hours, @auction.payment_due_at
  end

  test "a Dutch buy also gets a 48 hour window" do
    dutch = auctions(:dutch)
    now = dutch.start_at + 1.minute
    BuyNow.call(user: users(:buyer), auction: dutch, expected_price: 10_000, idempotency_key: "d", now: now)
    assert_equal now + 48.hours, dutch.reload.payment_due_at
  end

  test "winning moves the product to sold (M2 lifecycle: in_event -> sold)" do
    assert_equal "sold", @auction.product.status
  end

  test "the seller marks it paid in time: product stays sold" do
    result = MarkPaid.call(@auction, by: users(:seller), now: @closed_at + 47.hours)
    assert_equal :paid, result
    assert_equal @closed_at + 47.hours, @auction.reload.paid_at
    assert_equal "sold", @auction.product.status
  end

  test "only the seller can mark it paid" do
    assert_equal :forbidden, MarkPaid.call(@auction, by: users(:buyer), now: @closed_at + 1.hour)
    assert_nil @auction.reload.paid_at
  end

  test "cannot mark paid after the window" do
    assert_equal :payment_expired, MarkPaid.call(@auction, by: users(:seller), now: @closed_at + 48.hours)
  end

  test "marking paid twice is a no-op" do
    MarkPaid.call(@auction, by: users(:seller), now: @closed_at + 1.hour)
    assert_equal :already_paid, MarkPaid.call(@auction, by: users(:seller), now: @closed_at + 2.hours)
    assert_equal @closed_at + 1.hour, @auction.reload.paid_at
  end

  test "unpaid after 48h: sale cancelled, winner cleared, product available" do
    assert_equal :cancelled, ExpirePayment.call(@auction, now: @closed_at + 48.hours)
    @auction.reload
    assert @auction.cancelled?
    assert_nil @auction.winner
    assert_equal "available", @auction.product.status
  end

  test "before the deadline expiry is a no-op" do
    assert_equal :not_due, ExpirePayment.call(@auction, now: @closed_at + 48.hours - 1.second)
    assert @auction.reload.sold?
  end

  test "a paid auction is never cancelled" do
    MarkPaid.call(@auction, by: users(:seller), now: @closed_at + 1.hour)
    assert_equal :paid, ExpirePayment.call(@auction, now: @closed_at + 49.hours)
    assert @auction.reload.sold?
    assert_equal "sold", @auction.product.status
  end

  test "cancel is idempotent" do
    ExpirePayment.call(@auction, now: @closed_at + 48.hours)
    snapshot = @auction.reload.attributes
    assert_equal :not_pending, ExpirePayment.call(@auction, now: @closed_at + 50.hours)
    assert_equal snapshot, @auction.reload.attributes
  end

  test "the unpaid winner is passed to the extension point" do
    received = nil
    original = ExpirePayment.method(:after_cancel)
    ExpirePayment.define_singleton_method(:after_cancel) { |auction, unpaid_winner| received = [ auction, unpaid_winner ] }
    ExpirePayment.call(@auction, now: @closed_at + 48.hours)
    assert_equal [ @auction, users(:buyer) ], received
  ensure
    ExpirePayment.define_singleton_method(:after_cancel, original) if original
  end
end

class PaymentJobsTest < ActiveJob::TestCase
  test "winning schedules the expiry job at payment_due_at" do
    auction = auctions(:english)
    now = Time.current.change(usec: 0)
    auction.update!(stop_at: now - 1.second)
    auction.bids.create!(user: users(:buyer), amount: 1_500, idempotency_key: "j")
    assert_enqueued_with(job: ExpirePaymentJob, args: [ auction.id ], at: now + 48.hours) do
      CloseAuction.call(auction, now: now)
    end
  end

  test "the sweep cancels every overdue unpaid sale" do
    auction = auctions(:english)
    auction.update_columns(status: "sold", winner_id: users(:buyer).id, closed_at: 3.days.ago, payment_due_at: 1.day.ago)
    ExpireUnpaidAuctionsJob.perform_now
    assert auction.reload.cancelled?
  end
end
