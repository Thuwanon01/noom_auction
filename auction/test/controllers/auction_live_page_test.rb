require "test_helper"

class AuctionLivePageTest < ActionDispatch::IntegrationTest
  test "the detail page subscribes to the auction stream, morphs on refresh and has a polling fallback" do
    auction = auctions(:english)
    get auction_path(auction)
    assert_select "turbo-cable-stream-source[signed-stream-name]", 1
    assert_select "meta[name=turbo-refresh-method][content=morph]"
    assert_select "meta[name=turbo-refresh-scroll][content=preserve]"
    assert_select "[data-controller~=live][data-live-interval-value]"
  end
end
