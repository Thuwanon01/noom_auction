require "test_helper"

# The My Event pages are still UI-only drafts. They broke once when M3 removed the constants they read from
# AuctionsController, so they get a smoke test.
class EventsControllerTest < ActionDispatch::IntegrationTest
  test "my events renders with thai status and type labels" do
    get my_events_path
    assert_response :success
    assert_select ".badge", text: "กำลังประมูล"
    assert_select ".badge", text: "เร็วๆ นี้"
    assert_select ".badge", text: "จบแล้ว"
    assert_select "td", text: "ประมูลขึ้นราคา"
  end

  test "new event lists the three auction types" do
    get new_event_path
    assert_response :success
    assert_select "select option", text: "ประมูลซองปิด"
    assert_select "select option[value=dutch]", text: "ประมูลลดราคา"
  end
end
