module AuctionsHelper
  THAI_MONTHS = %w[ม.ค. ก.พ. มี.ค. เม.ย. พ.ค. มิ.ย. ก.ค. ส.ค. ก.ย. ต.ค. พ.ย. ธ.ค.].freeze

  PHASE_LABELS = {
    "live"     => "กำลังประมูล",
    "upcoming" => "เร็วๆ นี้",
    "ended"    => "จบแล้ว"
  }.freeze

  TYPE_LABELS = {
    "english" => "ประมูลขึ้นราคา",
    "dutch"   => "ประมูลลดราคา",
    "sealed"  => "ประมูลซองปิด"
  }.freeze

  # 11 พ.ย. 14:00
  def thai_datetime(time)
    time = time.in_time_zone
    "#{time.day} #{THAI_MONTHS[time.month - 1]} #{time.strftime('%H:%M')}"
  end

  # "5 ชม." / "1 วัน" / "12 นาที"
  def thai_duration(seconds)
    minutes = (seconds / 60.0).ceil
    if minutes < 60 then "#{[ minutes, 1 ].max} นาที"
    elsif minutes < 24 * 60 then "#{(minutes / 60.0).ceil} ชม."
    else "#{(minutes / (24 * 60.0)).ceil} วัน"
    end
  end

  def phase_label(phase) = PHASE_LABELS.fetch(phase, phase)
  def auction_type_label(type) = TYPE_LABELS.fetch(type, type)

  # Card time label (spec §1): live = countdown, upcoming = start time, ended = stop time.
  def card_time_label(auction, now: Time.current)
    case auction.phase(now)
    when "live"     then "เหลือ #{thai_duration(auction.stop_at - now)}"
    when "upcoming" then "เริ่ม #{thai_datetime(auction.start_at)}"
    else "ปิด #{thai_datetime(auction.stop_at)}"
    end
  end

  # Live auctions closing within 6 hours get an urgent style.
  def closing_soon?(auction, now: Time.current)
    auction.live?(now) && auction.stop_at - now <= 6.hours
  end

  # Sealed auctions hide bids, so they always show the starting price.
  def price_label(auction, now: Time.current)
    return "ราคาเริ่มต้น" if auction.sealed?
    { "upcoming" => "ราคาเริ่มต้น", "ended" => "ราคาปิด" }.fetch(auction.phase(now), "ราคาล่าสุด")
  end

  def baht(amount) = "฿#{number_with_delimiter(amount)}"

  # "cc***": first two characters, the rest hidden.
  def mask_name(name)
    name = name.to_s.strip
    return "***" if name.empty?
    "#{name.first(2)}***"
  end

  # Spec open point 1 (guest visibility) defaults to visible; change it only here.
  # Sealed bid amounts stay hidden until the auction ends.
  def bid_history_visible?(auction, _viewer, now: Time.current)
    !auction.sealed? || auction.ended?(now)
  end

  # Gallery image URLs, cover first. Empty until product photos (M2.1) exist.
  def gallery_urls(product)
    return [] unless product.respond_to?(:images)
    product.images.map { |img| url_for(img.respond_to?(:file) ? img.file : img) }
  end

  # Query params for the catalog with some filters changed. Always drops page,
  # because changing a filter or sort resets to page 1.
  def catalog_params(search, **changes)
    search.filter_params.merge(changes).compact_blank
  end

  # Params after removing one value from a filter (for chips).
  def catalog_params_without(search, key, value = nil)
    current = search.filter_params
    remaining = value ? Array(current[key]) - [ value ] : nil
    current.merge(key => remaining).compact_blank
  end

  # Active filters as chips: [label, params-without-it].
  def catalog_chips(search)
    chips = []
    chips << [ "ค้นหา: #{search.q}", catalog_params_without(search, :q) ] if search.q
    chips << [ phase_label(search.status), catalog_params_without(search, :status) ] if search.status
    search.types.each { |t| chips << [ auction_type_label(t), catalog_params_without(search, :type, t) ] }
    search.categories.each { |c| chips << [ Product::CATEGORIES[c], catalog_params_without(search, :category, c) ] }
    chips << [ AuctionSearch::PRICE_RANGES[search.price][:label], catalog_params_without(search, :price) ] if search.price
    chips
  end

  def back_to_catalog_path
    query = session[:catalog_query].presence
    query ? "#{auctions_path}?#{query}" : auctions_path
  end
end
