require "test_helper"

class CloseAuctionTest < ActiveSupport::TestCase
  setup do
    @auction = auctions(:english) # start 1,000
    @auction.update!(stop_at: 1.minute.ago, reserve_price: 2_000)
    @after = @auction.stop_at + 1.second
  end

  def bid(user, amount, at: 10.minutes.ago)
    @auction.bids.create!(user: user, amount: amount, placed_at: at, idempotency_key: SecureRandom.uuid)
  end

  def close(now: @after) = CloseAuction.call(@auction, now: now)

  test "highest bid at or above reserve wins; product pending payment" do
    bid(users(:other_buyer), 1_500)
    bid(users(:buyer), 2_000)
    assert_equal :sold, close
    @auction.reload
    assert @auction.sold?
    assert_equal users(:buyer), @auction.winner
    assert_equal 2_000, @auction.current_price
    assert_equal @after, @auction.closed_at
    assert_equal "pending_payment", @auction.product.status
  end

  test "no reserve: any highest bid wins" do
    @auction.update!(reserve_price: nil)
    bid(users(:buyer), 1_100)
    assert_equal :sold, close
  end

  test "highest bid below reserve: no winner, product available" do
    bid(users(:buyer), 1_999)
    assert_equal :no_winner, close
    @auction.reload
    assert @auction.no_winner?
    assert_nil @auction.winner
    assert_equal "available", @auction.product.status
  end

  test "no bids: ended unsold, product available" do
    assert_equal :unsold, close
    assert @auction.reload.unsold?
    assert_equal "available", @auction.product.status
  end

  test "sealed tie goes to the earliest bid" do
    @auction = auctions(:sealed)
    @auction.update!(stop_at: 1.minute.ago)
    bid(users(:other_buyer), 3_000, at: 20.minutes.ago)
    bid(users(:buyer), 3_000, at: 10.minutes.ago)
    close(now: Time.current)
    assert_equal users(:other_buyer), @auction.reload.winner
  end

  test "dutch still open at stop_at ends unsold" do
    @auction = auctions(:dutch)
    @auction.update!(stop_at: 1.minute.ago)
    assert_equal :unsold, close(now: Time.current)
  end

  test "running twice does not change the result" do
    bid(users(:buyer), 2_500)
    close
    first = @auction.reload.attributes
    assert_equal :already_closed, close(now: @after + 1.hour)
    assert_equal first, @auction.reload.attributes
  end

  test "before stop_at it is a no-op" do
    bid(users(:buyer), 2_500)
    assert_equal :not_due, close(now: @auction.stop_at - 1.second)
    assert @auction.reload.open?
  end

  test "an extended auction is not closed at its old stop_at" do
    old_stop = @auction.stop_at
    @auction.update!(stop_at: old_stop + 2.minutes, extension_count: 1)
    assert_equal :not_due, close(now: old_stop + 1.second)
    assert_equal :unsold, close(now: old_stop + 2.minutes)
  end
end

class CloseAuctionJobTest < ActiveJob::TestCase
  test "closes the auction when due" do
    auction = auctions(:english)
    auction.update!(stop_at: 1.minute.ago)
    CloseAuctionJob.perform_now(auction.id)
    assert auction.reload.unsold?
  end

  test "creating an auction schedules the close job at stop_at" do
    stop = 1.day.from_now.change(usec: 0)
    product = Product.create!(code: "P-9", seller: users(:seller), name: "Lamp", status: "live")
    assert_enqueued_with(job: CloseAuctionJob, at: stop) do
      Auction.create!(product: product, auction_type: :english, start_price: 100, start_at: Time.current, stop_at: stop)
    end
  end

  test "extending stop_at schedules the job again at the new time" do
    auction = auctions(:english)
    new_stop = auction.stop_at.change(usec: 0) + 2.minutes
    assert_enqueued_with(job: CloseAuctionJob, args: [ auction.id ], at: new_stop) do
      auction.update!(stop_at: new_stop)
    end
  end

  test "other updates do not schedule a job" do
    assert_no_enqueued_jobs(only: CloseAuctionJob) do
      auctions(:english).update!(current_price: 1_500)
    end
  end
end

class CloseOverdueAuctionsJobTest < ActiveJob::TestCase
  test "closes every overdue open auction and leaves the rest" do
    overdue = auctions(:english)
    overdue.update!(stop_at: 1.minute.ago)
    running = auctions(:sealed)

    CloseOverdueAuctionsJob.perform_now

    assert overdue.reload.unsold?
    assert running.reload.open?
  end
end
