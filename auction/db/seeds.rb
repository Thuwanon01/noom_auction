# Idempotent local dev data. Run with `bin/rails db:seed`.
return unless Rails.env.development?

# Both accounts use the password "password123".
User.find_or_create_by!(email: "done@example.com") do |u|
  u.password = "password123"
  u.phone = "0812345678"
  u.national_id = "1101700203450"
  u.phone_verified_at = Time.current
  u.pdpa_consented_at = Time.current
  u.occupation = "private_employee"
  u.annual_income = 480_000
  u.years_experience = 4
  u.credit_score = 670
  u.credit_grade = "B"
  u.score_model_version = "v1-draft"
  u.confirmed_at = Time.current
  u.onboarding_status = "completed"
end

User.find_or_create_by!(email: "new@example.com") do |u|
  u.password = "password123"
end

# M2.1 (#18): demo products and auctions that mirror the mock data in AuctionsController.
seller = User.find_or_create_by!(email: "seller@example.com") do |u|
  u.name = "Somchai Seller"
  u.password = "password123"
  u.onboarding_status = "completed"
  u.credit_score = 780
  u.credit_grade = "A"
end

now = Time.current.beginning_of_hour
[
  [ "กล้องฟิล์ม Nikon FM2",        "camera",             "english", 4_500,  -2.days,  5.hours ],
  [ "นาฬิกา Seiko 5 วินเทจ",       "watch",              "english", 3_200,  -1.day,   1.day ],
  [ "กีตาร์โปร่ง Yamaha F310",     "musical_instrument", "dutch",   2_800,  -3.hours, 2.days ],
  [ "จักรยานไฮบริด มือสอง",         "sports",             "english", 6_900,  1.day,    4.days ],
  [ "แผ่นเสียง The Beatles ชุดแรก", "collectible",        "sealed",  12_000, 2.days,   6.days ],
  [ "พระเครื่องเก่า (มีใบรับรอง)",   "collectible",        "english", 25_000, -5.days,  -1.day ],
  [ "iPad Air รุ่น 5 สภาพดี",       "it",                 "english", 9_500,  -6.hours, 10.hours ],
  [ "โต๊ะไม้สักโบราณ",              "furniture",          "dutch",   18_000, -7.days,  -2.days ],
  [ "ภาพวาดสีน้ำมัน ทิวทัศน์",       "art",                "sealed",  7_700,  3.hours,  3.days ],
  [ "หูฟังมือสอง สภาพดี",          "it",                 "english", 850,    -4.hours, 8.hours ],
  [ "MacBook Pro M3 14 นิ้ว",       "it",                 "english", 62_000, -1.day,   2.days ],
  [ "รถมอเตอร์ไซค์คลาสสิก",         "vehicle",            "sealed",  145_000, 1.day,   7.days ]
].each_with_index do |(name, category, type, price, start_offset, stop_offset), i|
  product = Product.find_or_create_by!(code: format("P-%04d", i + 1)) do |p|
    p.seller = seller
    p.name = name
    p.category = category
    p.condition = "good"
    p.description = "สินค้าตัวอย่างสำหรับทดสอบระบบประมูล"
    p.status = "in_event"
  end
  next if product.auction

  # offsets are relative to now; stop is measured from now too, as in the mock list
  attrs = { product: product, auction_type: type, start_price: price, current_price: price,
            start_at: now + start_offset, stop_at: now + stop_offset }
  attrs.merge!(bid_increment: 100) if type == "english"
  attrs.merge!(floor_price: (price * 0.5).to_i, price_drop: [ price / 20, 1 ].max, drop_interval_minutes: 10) if type == "dutch"
  Auction.create!(**attrs)
end
