# Draft: uses in-memory mock data until the auction API/model exists.
class AuctionsController < ApplicationController
  PER_PAGE = 6

  STATUSES = {
    "live"     => "กำลังประมูล",
    "upcoming" => "เร็วๆ นี้",
    "ended"    => "จบแล้ว"
  }.freeze

  SORTS = {
    "ending"     => "ใกล้ปิดก่อน",
    "price_asc"  => "ราคาต่ำ → สูง",
    "price_desc" => "ราคาสูง → ต่ำ"
  }.freeze

  TYPES = {
    "English" => "ประมูลขึ้นราคา",
    "Dutch"   => "ประมูลลดราคา",
    "Sealed"  => "ประมูลซองปิด"
  }.freeze

  PRICE_RANGES = {
    "0-1000"       => { label: "≤ ฿1,000",           range: 0..1_000 },
    "1001-3000"    => { label: "฿1,001 – 3,000",     range: 1_001..3_000 },
    "3001-10000"   => { label: "฿3,001 – 10,000",    range: 3_001..10_000 },
    "10001-50000"  => { label: "฿10,001 – 50,000",   range: 10_001..50_000 },
    "50001-100000" => { label: "฿50,001 – 100,000",  range: 50_001..100_000 },
    "100001-"      => { label: "> ฿100,000",         range: 100_001.. }
  }.freeze

  def index
    items = mock_auctions
    @counts = items.group_by { |a| a[:status] }.transform_values(&:size)
    @counts["all"] = items.size

    @status = STATUSES.key?(params[:status]) ? params[:status] : nil
    items = items.select { |a| a[:status] == @status } if @status

    @price = PRICE_RANGES.key?(params[:price]) ? params[:price] : nil
    items = items.select { |a| PRICE_RANGES[@price][:range].cover?(a[:price]) } if @price

    @sort = SORTS.key?(params[:sort]) ? params[:sort] : "ending"
    items =
      case @sort
      when "price_asc"  then items.sort_by { |a| a[:price] }
      when "price_desc" then items.sort_by { |a| -a[:price] }
      else items.sort_by { |a| [ STATUSES.keys.index(a[:status]), a[:stop_at] ] }
      end

    @total_pages = [ (items.size / PER_PAGE.to_f).ceil, 1 ].max
    @page = params[:page].to_i.clamp(1, @total_pages)
    @auctions = items.slice((@page - 1) * PER_PAGE, PER_PAGE) || []
  end

  def show
    @auction = mock_auctions.find { |a| a[:id] == params[:id].to_i }
    return head :not_found unless @auction

    @bids = mock_bids(@auction)
    @min_bid = @auction[:price] + 100
  end

  private

  # Newest first; mirrors the "user / price / time" table in the sketch.
  def mock_bids(auction)
    return [] if auction[:status] == "upcoming"

    now = Time.current.beginning_of_hour
    [ [ "cc", 0, 30 ], [ "bb", 100, 90 ], [ "aa", 200, 150 ] ].map do |user, off, mins|
      { user: user, price: auction[:price] - off, at: now + 17.hours - mins.minutes }
    end
  end

  def mock_auctions
    now = Time.current.beginning_of_hour
    [
      { title: "กล้องฟิล์ม Nikon FM2",        type: "English",  product: "กล้อง",     emoji: "📷", price: 4_500,  start_at: now - 2.days,  stop_at: now + 5.hours },
      { title: "นาฬิกา Seiko 5 วินเทจ",       type: "English",  product: "นาฬิกา",    emoji: "⌚", price: 3_200,  start_at: now - 1.day,   stop_at: now + 1.day },
      { title: "กีตาร์โปร่ง Yamaha F310",     type: "Dutch",    product: "เครื่องดนตรี", emoji: "🎸", price: 2_800,  start_at: now - 3.hours, stop_at: now + 2.days },
      { title: "จักรยานไฮบริด มือสอง",         type: "English",  product: "กีฬา",      emoji: "🚲", price: 6_900,  start_at: now + 1.day,   stop_at: now + 4.days },
      { title: "แผ่นเสียง The Beatles ชุดแรก", type: "Sealed",   product: "ของสะสม",   emoji: "💿", price: 12_000, start_at: now + 2.days,  stop_at: now + 6.days },
      { title: "พระเครื่องเก่า (มีใบรับรอง)",   type: "English",  product: "ของสะสม",   emoji: "🪷", price: 25_000, start_at: now - 5.days,  stop_at: now - 1.day },
      { title: "iPad Air รุ่น 5 สภาพดี",       type: "English",  product: "ไอที",      emoji: "📱", price: 9_500,  start_at: now - 6.hours, stop_at: now + 10.hours },
      { title: "โต๊ะไม้สักโบราณ",              type: "Dutch",    product: "เฟอร์นิเจอร์", emoji: "🪑", price: 18_000, start_at: now - 7.days,  stop_at: now - 2.days },
      { title: "ภาพวาดสีน้ำมัน ทิวทัศน์",       type: "Sealed",   product: "ศิลปะ",     emoji: "🖼️", price: 7_700,  start_at: now + 3.hours, stop_at: now + 3.days },
      { title: "หูฟังมือสอง สภาพดี",          type: "English",  product: "ไอที",      emoji: "🎧", price: 850,    start_at: now - 4.hours, stop_at: now + 8.hours },
      { title: "MacBook Pro M3 14 นิ้ว",       type: "English",  product: "ไอที",      emoji: "💻", price: 62_000, start_at: now - 1.day,   stop_at: now + 2.days },
      { title: "รถมอเตอร์ไซค์คลาสสิก",         type: "Sealed",   product: "ยานพาหนะ",  emoji: "🏍️", price: 145_000, start_at: now + 1.day,  stop_at: now + 7.days }
    ].each_with_index.map do |a, i|
      status =
        if now < a[:start_at] then "upcoming"
        elsif now > a[:stop_at] then "ended"
        else "live"
        end
      a.merge(id: i + 1, status: status)
    end
  end
end
