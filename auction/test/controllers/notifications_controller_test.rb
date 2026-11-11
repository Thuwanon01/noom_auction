require "test_helper"

# M4.12 (#48) UI: in-app list and unread count in the header.
class NotificationsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @me = users(:buyer)
    @auction = auctions(:english)
  end

  def notify(kind, user: @me, at: Time.current)
    Notification.create!(user: user, auction: @auction, kind: kind, created_at: at)
  end

  test "guests are sent to log in" do
    get my_notifications_path
    assert_redirected_to login_path
  end

  test "the header shows the unread count for the signed-in user" do
    notify(:outbid)
    notify(:lost)
    notify(:outbid, user: users(:other_buyer))
    sign_in_as @me
    get auctions_path
    assert_select "a.notif-bell[href=?]", my_notifications_path do
      assert_select ".notif-bell__count", text: "2"
    end
  end

  test "no count badge when everything is read, no bell for guests" do
    sign_in_as @me
    get auctions_path
    assert_select "a.notif-bell"
    assert_select ".notif-bell__count", 0
  end

  test "guests see no bell" do
    get auctions_path
    assert_select "a.notif-bell", 0
  end

  test "lists my notifications newest first with a link to the auction" do
    notify(:outbid, at: 2.hours.ago)
    notify(:won, at: 1.hour.ago)
    notify(:lost, user: users(:other_buyer))
    sign_in_as @me
    get my_notifications_path
    assert_select ".notification", 2
    assert_select ".notification:first-child", text: /You won Vintage Film Camera/
    assert_select ".notification:last-child", text: /You were outbid on Vintage Film Camera/
    assert_select ".notification a[href=?]", auction_path(@auction), minimum: 1
  end

  test "opening the list highlights unread ones, then marks them read" do
    notify(:outbid)
    sign_in_as @me
    get my_notifications_path
    assert_select ".notification--unread", 1
    assert_equal 0, @me.notifications.unread.count

    get my_notifications_path
    assert_select ".notification--unread", 0
  end

  test "empty state" do
    sign_in_as @me
    get my_notifications_path
    assert_select ".empty", text: /ยังไม่มีการแจ้งเตือน/
  end
end
