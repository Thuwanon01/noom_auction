# Search, filter, sort and paginate the public catalog (M3.3 #29, M3.5 #31).
#
#   search = AuctionSearch.new(params)
#   search.records      # one page of auctions
#   search.counts       # { "all" => 12, "live" => 6, "upcoming" => 4, "ended" => 2 }
#   search.page / search.total_pages / search.total
#
# Params (all optional, unknown values are ignored):
#   q         text over product name and category label, case-insensitive
#   status    live | upcoming | ended
#   type[]    english | dutch | sealed (multi)
#   category[] Product::CATEGORIES keys (multi)
#   price     one of PRICE_RANGES keys
#   sort      ending (default) | price_asc | price_desc
#   page      1-based, clamped to 1..total_pages
#
# Filters combine with AND. The status tab counts apply every other active
# filter (q, type, category, price) but not status itself, so each tab shows
# how many results you get by clicking it.
class AuctionSearch
  PER_PAGE = 6

  SORTS = {
    "ending"     => "ใกล้ปิดก่อน",
    "price_asc"  => "ราคาต่ำ → สูง",
    "price_desc" => "ราคาสูง → ต่ำ"
  }.freeze
  DEFAULT_SORT = "ending"

  PRICE_RANGES = {
    "0-1000"       => { label: "≤ ฿1,000",          range: 0..1_000 },
    "1001-3000"    => { label: "฿1,001 – 3,000",    range: 1_001..3_000 },
    "3001-10000"   => { label: "฿3,001 – 10,000",   range: 3_001..10_000 },
    "10001-50000"  => { label: "฿10,001 – 50,000",  range: 10_001..50_000 },
    "50001-100000" => { label: "฿50,001 – 100,000", range: 50_001..100_000 },
    "100001-"      => { label: "> ฿100,000",        range: 100_001.. }
  }.freeze

  FILTER_KEYS = %i[q status type category price sort].freeze

  attr_reader :q, :status, :types, :categories, :price, :sort, :now

  def initialize(params = {}, scope: Auction.publicly_listed, now: Time.current)
    params = params.to_unsafe_h if params.respond_to?(:to_unsafe_h)
    params = params.to_h.with_indifferent_access
    @scope = scope
    @now = now
    @q = params[:q].to_s.strip.first(100).presence
    @status = pick(params[:status], Auction::PHASES)
    @types = pick_many(params[:type], Auction.auction_types.keys)
    @categories = pick_many(params[:category], Product::CATEGORIES.keys)
    @price = pick(params[:price], PRICE_RANGES.keys)
    @sort = pick(params[:sort], SORTS.keys) || DEFAULT_SORT
    @requested_page = params[:page]
  end

  # Normalized filter params, for building links. Defaults are left out.
  def filter_params
    {
      q: q, status: status, type: types.presence, category: categories.presence,
      price: price, sort: (sort unless sort == DEFAULT_SORT)
    }.compact
  end

  def filtered? = [ q, status, price ].any? || types.any? || categories.any?

  def relation
    @relation ||= order(apply_status(filtered_scope))
  end

  def counts
    @counts ||= begin
      grouped = filtered_scope.group(Arel.sql(Auction.phase_sql(now))).count
      Auction::PHASES.index_with { |p| grouped.fetch(p, 0) }.merge("all" => grouped.values.sum)
    end
  end

  def total = status ? counts.fetch(status) : counts.fetch("all")
  def total_pages = [ (total / PER_PAGE.to_f).ceil, 1 ].max

  # Invalid, zero, negative or too-high pages are clamped to the nearest valid page.
  def page
    @page ||= Integer(@requested_page.to_s, 10, exception: false).to_i.clamp(1, total_pages)
  end

  def records
    @records ||= relation.includes(:product).offset((page - 1) * PER_PAGE).limit(PER_PAGE).to_a
  end

  private

  def pick(value, allowed) = allowed.include?(value.to_s) ? value.to_s : nil

  def pick_many(values, allowed)
    list = values.is_a?(Array) ? values : values.to_s.split(",")
    list.map(&:to_s) & allowed
  end

  # Every filter except status.
  def filtered_scope
    s = @scope
    s = s.where(auction_type: types) if types.any?
    s = s.where(products: { category: categories }) if categories.any?
    s = apply_price(s) if price
    s = apply_text(s) if q
    s
  end

  def apply_status(s)
    case status
    when "live"     then s.live_at(now)
    when "upcoming" then s.upcoming_at(now)
    when "ended"    then s.ended_at(now)
    else s
    end
  end

  def apply_price(s)
    range = PRICE_RANGES.fetch(price)[:range]
    s = s.where("#{Auction::LISTED_PRICE_SQL} >= ?", range.begin)
    range.end ? s.where("#{Auction::LISTED_PRICE_SQL} <= ?", range.end) : s
  end

  def apply_text(s)
    needle = q.downcase
    pattern = "%#{Auction.sanitize_sql_like(needle)}%"
    matching_categories = Product::CATEGORIES.select { |key, label| key.include?(needle) || label.downcase.include?(needle) }.keys
    name_match = Product.arel_table[:name].lower.matches(pattern, "\\")
    s.where(name_match.or(Product.arel_table[:category].in(matching_categories)))
  end

  def order(s)
    price = Arel.sql(Auction::LISTED_PRICE_SQL)
    case sort
    when "price_asc"  then s.order(price.asc, stop_at: :asc, id: :asc)
    when "price_desc" then s.order(price.desc, stop_at: :asc, id: :asc)
    else
      s.order(Arel.sql(Auction.phase_rank_sql(now)), stop_at: :asc, id: :asc)
    end
  end
end
