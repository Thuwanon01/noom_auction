require "test_helper"

class NotificationTest < ActiveSupport::TestCase
  setup { @auction = auctions(:english) }

  def note(kind, user: users(:buyer)) = Notification.create!(user: user, auction: @auction, kind: kind)

  test "spec messages for outbid and lost" do
    assert_equal "You were outbid on Vintage Film Camera", note(:outbid).message
    assert_equal "Auction ended. You did not win", note(:lost).message
  end

  test "winner and seller messages" do
    @auction.update!(current_price: 2_500)
    assert_equal "You won Vintage Film Camera for ฿2,500. Please pay within 48 hours", note(:won).message
    assert_equal "Vintage Film Camera sold for ฿2,500", note(:seller_sold, user: users(:seller)).message
    assert_equal "Vintage Film Camera ended below the reserve price. No winner", note(:seller_no_winner, user: users(:seller)).message
    assert_equal "Vintage Film Camera ended with no bids", note(:seller_unsold, user: users(:seller)).message
  end

  test "unread scope and mark_read!" do
    n = note(:outbid)
    assert_equal [ n ], users(:buyer).notifications.unread.to_a
    n.mark_read!
    assert_empty users(:buyer).notifications.unread
  end
end
