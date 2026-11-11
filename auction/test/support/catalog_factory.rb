# Builds catalog records for M3 tests without growing the shared fixtures.
module CatalogFactory
  def create_auction(name: "Item #{SecureRandom.hex(3)}", category: "other", type: "english", price: 1_000,
                     start_at: 1.hour.ago, stop_at: 1.day.from_now, product_status: "in_event", seller: users(:seller), **attrs)
    product = Product.create!(code: "T-#{SecureRandom.hex(4)}", seller: seller, name: name, category: category,
                              condition: "good", status: product_status)
    Auction.create!(product: product, auction_type: type, start_price: price, current_price: price,
                    start_at: start_at, stop_at: stop_at, **attrs)
  end

  def place_bid(auction, user, amount, at: Time.current)
    auction.bids.create!(user: user, amount: amount, placed_at: at, idempotency_key: SecureRandom.hex(6))
  end
end
