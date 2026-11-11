require "application_system_test_case"

# M4.14 (#50): the bidding flow end to end through the UI. Time is moved
# with travel_to, and the jobs Solid Queue would run at stop_at /
# payment_due_at are run directly (CloseAuctionJob, ExpirePaymentJob).
class BiddingFlowTest < ApplicationSystemTestCase
  include ActiveSupport::Testing::TimeHelpers

  def as(user)
    sign_in_as users(user)
    yield
  end

  def bid_english(amount)
    fill_in "amount", with: amount.to_s
    click_button "เสนอราคา"
  end

  def my_bid_status(auction_name)
    visit my_bids_path
    find(".my-bid", text: auction_name).find("[data-status]").text
  end

  def notifications_text
    visit my_notifications_path
    page.text
  end

  test "English: two bidders, outbid, anti-sniping, close, winner pays" do
    auction = auctions(:english) # 1,000 + 100
    auction.update_columns(stop_at: 10.minutes.from_now, reserve_price: 1_200)

    as(:buyer) { visit auction_path(auction); bid_english(1_100) }
    assert_selector ".bid-flash--success", text: "You are the highest bidder"

    as(:other_buyer) { visit auction_path(auction); bid_english(1_200) }
    assert_selector ".bid-flash--success", text: "You are the highest bidder"

    as(:buyer) do
      assert_includes notifications_text, "You were outbid on Vintage Film Camera"
      assert_equal "Outbid", my_bid_status("Vintage Film Camera")
    end

    # A bid 1 minute before the end extends stop_at by 2 minutes.
    original_stop = auction.reload.stop_at
    travel_to original_stop - 1.minute do
      as(:buyer) { visit auction_path(auction); bid_english(1_300) }
      assert_selector ".bid-flash--success", text: "You are the highest bidder"
    end
    assert_equal original_stop + 2.minutes, auction.reload.stop_at
    assert_equal 1, auction.extension_count

    # The job scheduled for the old stop_at does nothing; the new one closes it.
    travel_to original_stop + 1.second do
      CloseAuctionJob.perform_now(auction.id)
      assert auction.reload.open?
    end
    travel_to auction.stop_at + 1.second do
      CloseAuctionJob.perform_now(auction.id)
    end
    assert auction.reload.sold?
    assert_equal users(:buyer), auction.winner

    as(:buyer) do
      assert_equal "Won", my_bid_status("Vintage Film Camera")
      assert_text "ชำระภายใน"
      assert_includes notifications_text, "You won Vintage Film Camera for ฿1,300"
    end
    as(:other_buyer) do
      assert_equal "Lost", my_bid_status("Vintage Film Camera")
      assert_includes notifications_text, "Auction ended. You did not win"
    end
    as(:seller) do
      assert_includes notifications_text, "Vintage Film Camera sold for ฿1,300"
      visit auction_path(auction)
      assert_selector ".result", text: "ราคาที่ชนะ ฿1,300"
      click_button "ยืนยันว่าได้รับชำระเงินแล้ว"
      assert_selector ".bid-flash--success", text: "Marked as paid"
    end
    assert auction.reload.paid_at
  end

  test "Dutch: two buyers on the same price; the first wins, the second sees Sold" do
    auction = auctions(:dutch)
    auction.update_columns(start_at: 25.minutes.ago) # 9,000

    using_session(:first) do
      sign_in_as users(:buyer)
      visit auction_path(auction)
    end
    using_session(:second) do
      sign_in_as users(:other_buyer)
      visit auction_path(auction)
      assert_button "Buy now at ฿9,000"
    end

    using_session(:first) do
      click_button "Buy now at ฿9,000"
      assert_selector ".bid-flash--success", text: "You bought this item for ฿9,000"
    end
    using_session(:second) do
      click_button "Buy now at ฿9,000" # stale page
      assert_selector ".bid-flash--error", text: "Sold"
      assert_selector ".result", text: "Sold"
    end

    assert_equal users(:buyer), auction.reload.winner
    assert_equal 1, auction.bids.count
  end

  test "Sealed: submit, revise, hidden until close, then revealed with the winner" do
    auction = auctions(:sealed) # start 2,000

    as(:buyer) do
      visit auction_path(auction)
      fill_in "amount", with: "2500"
      click_button "ยื่นซอง"
    end
    as(:other_buyer) do
      visit auction_path(auction)
      fill_in "amount", with: "3000"
      click_button "ยื่นซอง"
    end
    as(:buyer) do
      visit auction_path(auction)
      fill_in "amount", with: "3500"
      click_button "แก้ไขราคา"
      assert_selector "[data-testid=my-sealed-bid]", text: "฿3,500"
      assert_no_text "฿3,000"
      assert_equal "Submitted", my_bid_status("Oil Painting")
    end
    as(:other_buyer) do
      visit auction_path(auction)
      assert_no_text "฿3,500"
      assert_no_selector ".table"
      assert_selector "[data-testid=bid-count]", text: "2"
    end

    travel_to auction.stop_at + 1.second do
      CloseAuctionJob.perform_now(auction.id)
      as(:other_buyer) do
        visit auction_path(auction)
        within(".table") do
          assert_text "฿3,500"
          assert_text "฿3,000"
        end
        assert_selector ".result", text: "ราคาที่ชนะ ฿3,500"
        assert_equal "Lost", my_bid_status("Oil Painting")
      end
    end
    assert_equal users(:buyer), auction.reload.winner
  end

  test "reserve not met: no winner, product available, bidder lost" do
    auction = auctions(:english)
    auction.update_columns(reserve_price: 5_000, stop_at: 10.minutes.from_now)
    as(:buyer) { visit auction_path(auction); bid_english(1_100) }

    travel_to auction.stop_at + 1.second do
      CloseAuctionJob.perform_now(auction.id)
      as(:buyer) do
        visit auction_path(auction)
        assert_selector ".result", text: "ไม่มีผู้ชนะ"
        assert_equal "Lost", my_bid_status("Vintage Film Camera")
      end
      as(:seller) { assert_includes notifications_text, "ended below the reserve price. No winner" }
    end
    assert auction.reload.no_winner?
    assert_equal "available", auction.product.status
  end

  test "no bids: ended unsold" do
    auction = auctions(:english)
    travel_to auction.stop_at + 1.second do
      CloseAuctionJob.perform_now(auction.id)
      as(:seller) do
        visit auction_path(auction)
        assert_selector ".result", text: "ไม่มีผู้ชนะ"
        assert_includes notifications_text, "Vintage Film Camera ended with no bids"
      end
    end
    assert auction.reload.unsold?
    assert_equal "available", auction.product.status
  end

  test "unpaid after 48 hours: sale cancelled, product available, winner lost" do
    auction = auctions(:english)
    auction.update_columns(stop_at: 10.minutes.from_now, reserve_price: nil)
    as(:buyer) { visit auction_path(auction); bid_english(1_100) }

    travel_to auction.stop_at + 1.second do
      CloseAuctionJob.perform_now(auction.id)
    end
    due = auction.reload.payment_due_at

    travel_to due + 1.second do
      ExpirePaymentJob.perform_now(auction.id)
      as(:seller) do
        visit auction_path(auction)
        assert_no_button "ยืนยันว่าได้รับชำระเงินแล้ว"
      end
      as(:buyer) { assert_equal "Lost", my_bid_status("Vintage Film Camera") }
    end
    assert auction.reload.cancelled?
    assert_nil auction.winner
    assert_equal "available", auction.product.status
  end
end
