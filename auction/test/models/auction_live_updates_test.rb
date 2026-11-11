require "test_helper"
require "turbo/broadcastable/test_helper"

# M4.9 (#45): every change viewers should see broadcasts a data-free
# "refresh" to the auction's stream; each browser re-renders the page as
# its own user, so per-viewer and sealed content never goes over the wire.
class AuctionLiveUpdatesTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper
  include Turbo::Broadcastable::TestHelper

  def refreshes_for(auction, &block)
    perform_enqueued_jobs(only: Turbo::Streams::BroadcastStreamJob) do
      capture_turbo_stream_broadcasts(auction, &block)
    end
  end

  test "an accepted English bid broadcasts a refresh" do
    auction = auctions(:english)
    streams = refreshes_for(auction) do
      PlaceBid.call(user: users(:buyer), auction: auction, amount: 1_100, idempotency_key: "a")
    end
    assert_equal [ "refresh" ], streams.map { |s| s["action"] }.uniq
  end

  test "a rejected bid broadcasts nothing" do
    auction = auctions(:english)
    streams = refreshes_for(auction) do
      PlaceBid.call(user: users(:buyer), auction: auction, amount: 1, idempotency_key: "a")
    end
    assert_empty streams
  end

  test "a sealed bid broadcasts a refresh with no amount in it" do
    auction = auctions(:sealed)
    streams = refreshes_for(auction) do
      SubmitSealedBid.call(user: users(:buyer), auction: auction, amount: 154_321, idempotency_key: "s")
    end
    assert_not_empty streams
    streams.each do |s|
      assert_equal "refresh", s["action"]
      assert_no_match(/154321|154,321/, s.to_html)
      assert_empty s.children.to_a.reject(&:text?)
    end
  end

  test "a Dutch buy (Sold) broadcasts a refresh" do
    auction = auctions(:dutch)
    streams = refreshes_for(auction) do
      BuyNow.call(user: users(:buyer), auction: auction, expected_price: auction.dutch_price_at(Time.current), idempotency_key: "d")
    end
    assert_not_empty streams
  end

  test "closing broadcasts a refresh" do
    auction = auctions(:english)
    auction.update_columns(stop_at: 1.minute.ago)
    streams = refreshes_for(auction) { CloseAuction.call(auction) }
    assert_not_empty streams
  end
end
