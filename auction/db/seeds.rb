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

# M3: demo catalog. the 12 auctions that used to be mock data in AuctionsController,
# covering live, upcoming and ended auctions of all three types.
# Idempotent: re-running resets each demo auction's times and bids relative to now.

now = Time.current.beginning_of_hour

seller = User.find_or_create_by!(email: "seller@example.com") do |u|
  u.name = "Somchai Seller"
  u.password = "password123"
  u.onboarding_status = "completed"
  u.credit_grade = "A"
end

bidders = %w[aa bb cc].map do |handle|
  User.find_or_create_by!(email: "#{handle}@example.com") do |u|
    u.name = "#{handle * 2} bidder"
    u.password = "password123"
    u.onboarding_status = "completed"
    u.credit_grade = "B"
  end
end

User.find_or_create_by!(email: "newbie@example.com") do |u|
  u.name = "Nok Newbie"
  u.password = "password123"
  u.onboarding_status = "not_started"
end

demo = [
  { name: "กล้องฟิล์ม Nikon FM2",         type: "english", category: "camera",      price: 4_500,   start_at: now - 2.days,  stop_at: now + 5.hours,  brand: "Nikon",  model: "FM2",  year: "1985" },
  { name: "นาฬิกา Seiko 5 วินเทจ",        type: "english", category: "watch",       price: 3_200,   start_at: now - 1.day,   stop_at: now + 1.day,    brand: "Seiko",  model: "5" },
  { name: "กีตาร์โปร่ง Yamaha F310",      type: "dutch",   category: "musical_instrument",  price: 2_800,   start_at: now - 3.hours, stop_at: now + 2.days,   brand: "Yamaha", model: "F310", floor_price: 1_500, price_drop: 100, drop_interval_minutes: 30 },
  { name: "จักรยานไฮบริด มือสอง",          type: "english", category: "sports",      price: 6_900,   start_at: now + 1.day,   stop_at: now + 4.days },
  { name: "แผ่นเสียง The Beatles ชุดแรก",  type: "sealed",  category: "collectible", price: 12_000,  start_at: now + 2.days,  stop_at: now + 6.days },
  { name: "พระเครื่องเก่า (มีใบรับรอง)",    type: "english", category: "collectible", price: 25_000,  start_at: now - 5.days,  stop_at: now - 1.day },
  { name: "iPad Air รุ่น 5 สภาพดี",        type: "english", category: "it",          price: 9_500,   start_at: now - 6.hours, stop_at: now + 10.hours, brand: "Apple",  model: "iPad Air 5", year: "2022" },
  { name: "โต๊ะไม้สักโบราณ",               type: "dutch",   category: "furniture",   price: 18_000,  start_at: now - 7.days,  stop_at: now - 2.days,   floor_price: 9_000, price_drop: 500, drop_interval_minutes: 60 },
  { name: "ภาพวาดสีน้ำมัน ทิวทัศน์",        type: "sealed",  category: "art",         price: 7_700,   start_at: now + 3.hours, stop_at: now + 3.days },
  { name: "หูฟังมือสอง สภาพดี",           type: "english", category: "it",          price: 850,     start_at: now - 4.hours, stop_at: now + 8.hours },
  { name: "MacBook Pro M3 14 นิ้ว",        type: "english", category: "it",          price: 62_000,  start_at: now - 1.day,   stop_at: now + 2.days,   brand: "Apple",  model: "MacBook Pro 14 M3", year: "2023" },
  { name: "รถมอเตอร์ไซค์คลาสสิก",          type: "sealed",  category: "vehicle",     price: 145_000, start_at: now + 1.day,   stop_at: now + 7.days }
]

demo.each_with_index do |d, i|
  product = Product.find_or_initialize_by(code: format("P-%04d", i + 1))
  product.update!(
    seller: seller, name: d[:name], category: d[:category], condition: "good", status: "in_event",
    brand: d[:brand], model: d[:model], year: d[:year],
    description: "สินค้าตัวอย่างสำหรับทดลองระบบประมูล #{d[:name]}"
  )

  # Started English auctions open ฿300 lower so three bids bring them to the old demo price.
  with_bids = d[:type] == "english" && d[:start_at] <= now
  start_price = with_bids ? d[:price] - 300 : d[:price]

  auction = Auction.find_or_initialize_by(product: product)
  auction.bids.destroy_all if auction.persisted?
  auction.update!(
    auction_type: d[:type], start_price: start_price, current_price: start_price, bid_increment: 100,
    floor_price: d[:floor_price], price_drop: d[:price_drop], drop_interval_minutes: d[:drop_interval_minutes],
    start_at: d[:start_at], stop_at: d[:stop_at], status: "open"
  )

  # Three bids, newest highest, like the old mock history.
  next unless with_bids

  bidders.each_with_index do |user, n|
    auction.bids.create!(user: user, amount: start_price + (n + 1) * 100,
                         placed_at: [ d[:start_at] + (n + 1).hours, now ].min - (3 - n).minutes,
                         idempotency_key: "seed-#{auction.id}-#{n}")
  end
  auction.update!(current_price: auction.bids.maximum(:amount))
end

puts "Seeded #{Auction.count} auctions, #{Bid.count} bids, #{User.count} users."

# M2.8 (#25): a development admin to try the review queue. Never create admins from seeds in production.
unless Rails.env.production?
  User.find_or_create_by!(email: "admin@example.com") do |u|
    u.name = "Ada Admin"
    u.password = "password123"
    u.onboarding_status = "completed"
    u.admin = true
  end
end
