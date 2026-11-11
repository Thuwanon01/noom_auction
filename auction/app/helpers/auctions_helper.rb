module AuctionsHelper
  THAI_MONTHS = %w[ม.ค. ก.พ. มี.ค. เม.ย. พ.ค. มิ.ย. ก.ค. ส.ค. ก.ย. ต.ค. พ.ย. ธ.ค.].freeze

  # 11 พ.ย. 14:00
  def thai_datetime(time)
    "#{time.day} #{THAI_MONTHS[time.month - 1]} #{time.strftime('%H:%M')}"
  end

  # "ปิดในอีก 5 ชม." / "เริ่มในอีก 1 วัน" / "ปิดแล้ว"
  def time_left_label(auction, now: Time.current)
    case auction[:status]
    when "live"     then "ปิดในอีก #{thai_duration(auction[:stop_at] - now)}"
    when "upcoming" then "เริ่มในอีก #{thai_duration(auction[:start_at] - now)}"
    else "ปิดประมูลแล้ว"
    end
  end

  # Live auctions closing within 6 hours get an urgent style.
  def closing_soon?(auction, now: Time.current)
    auction[:status] == "live" && auction[:stop_at] - now <= 6.hours
  end

  def auction_type_label(type)
    AuctionsController::TYPES.fetch(type, type)
  end

  private

  def thai_duration(seconds)
    minutes = (seconds / 60).ceil
    if minutes < 60 then "#{[ minutes, 1 ].max} นาที"
    elsif minutes < 24 * 60 then "#{(minutes / 60.0).ceil} ชม."
    else "#{(minutes / (24 * 60.0)).ceil} วัน"
    end
  end
end
