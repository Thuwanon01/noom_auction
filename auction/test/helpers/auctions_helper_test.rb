require "test_helper"

# M3.2 (#28) card labels and M3.8 (#34) masking.
class AuctionsHelperTest < ActionView::TestCase
  include CatalogFactory

  setup { @now = Time.zone.local(2026, 11, 11, 9, 0) }

  test "live card shows a countdown" do
    a = create_auction(start_at: @now - 1.hour, stop_at: @now + 5.hours)
    assert_equal "เหลือ 5 ชม.", card_time_label(a, now: @now)
    assert closing_soon?(a, now: @now)
  end

  test "upcoming card shows the start time" do
    a = create_auction(start_at: @now + 1.day, stop_at: @now + 2.days)
    assert_equal "เริ่ม 12 พ.ย. 09:00", card_time_label(a, now: @now)
    assert_equal "ราคาเริ่มต้น", price_label(a, now: @now)
  end

  test "ended card shows the stop time" do
    a = create_auction(start_at: @now - 2.days, stop_at: @now - 1.day)
    assert_equal "ปิด 10 พ.ย. 09:00", card_time_label(a, now: @now)
    assert_equal "ราคาปิด", price_label(a, now: @now)
  end

  test "sealed card is labeled with the starting price in every phase" do
    a = create_auction(type: "sealed", price: 2_000, current_price: 5_000, start_at: @now - 1.hour, stop_at: @now + 1.hour)
    assert_equal "ราคาเริ่มต้น", price_label(a, now: @now)
    assert_equal 2_000, a.listed_price
  end

  test "card partial renders badges, sealed price label and a link" do
    a = create_auction(name: "Sealed Vinyl", category: "collectible", type: "sealed", price: 12_000, current_price: 99_000)
    render partial: "auctions/card", locals: { auction: a }
    assert_includes rendered, "ประมูลซองปิด"
    assert_includes rendered, "กำลังประมูล"
    assert_includes rendered, "ราคาเริ่มต้น"
    assert_includes rendered, "฿12,000"
    assert_not_includes rendered, "99,000"
    assert_includes rendered, %(href="/auctions/#{a.id}")
  end

  test "mask_name keeps two characters" do
    assert_equal "cc***", mask_name("ccmaster")
    assert_equal "ส***", mask_name("ส")
    assert_equal "***", mask_name(nil)
  end

  test "thai_duration rounds up" do
    assert_equal "1 นาที", thai_duration(5)
    assert_equal "2 ชม.", thai_duration(61 * 60)
    assert_equal "2 วัน", thai_duration(25 * 3600)
  end
end
