# Rules for the seller's Step 3 (productOnboardingFlow.md). They only run in the :seller_setup validation
# context, so auctions built elsewhere (fixtures, closing jobs, bids) are not forced to start in the future.
module AuctionSellerSetup
  extend ActiveSupport::Concern

  MIN_START_PRICE = 100
  MIN_BID_INCREMENT = 10
  DEFAULT_BID_INCREMENT = 100
  MIN_LEAD = 1.hour
  MIN_DURATION = 1.hour
  MAX_DURATION = 14.days
  DROP_INTERVAL_RANGE = 1..60 # minutes

  included do
    before_validation :prepare_for_setup, on: :seller_setup

    validates :auction_type, presence: true, on: :seller_setup
    validates :start_price, numericality: { only_integer: true, greater_than_or_equal_to: MIN_START_PRICE }, on: :seller_setup
    validates :reserve_price, numericality: { only_integer: true }, allow_nil: true, on: :seller_setup
    validate :reserve_not_below_start, :schedule_is_valid, :type_fields_are_valid, on: :seller_setup
  end

  private

  # The reserve and the fields of the other types are not part of the chosen type, so drop them.
  def prepare_for_setup
    self.current_price = start_price if bids.none?
    case auction_type
    when "english"
      self.floor_price = self.price_drop = self.drop_interval_minutes = nil
      self.bid_increment = DEFAULT_BID_INCREMENT if bid_increment.blank?
    when "dutch"
      self.bid_increment = DEFAULT_BID_INCREMENT # unused for Dutch; column is NOT NULL
    when "sealed"
      self.floor_price = self.price_drop = self.drop_interval_minutes = nil
      self.bid_increment = DEFAULT_BID_INCREMENT
    end
  end

  def reserve_not_below_start
    return if reserve_price.blank? || start_price.blank?

    errors.add(:reserve_price, "must be at least the starting price") if reserve_price < start_price
  end

  def schedule_is_valid
    return if start_at.blank? || stop_at.blank?

    errors.add(:start_at, "must be at least 1 hour from now") if start_at < Time.current + MIN_LEAD
    length = stop_at - start_at
    errors.add(:stop_at, "must be at least 1 hour after the start") if length < MIN_DURATION
    errors.add(:stop_at, "must be within 14 days of the start") if length > MAX_DURATION
  end

  def type_fields_are_valid
    case auction_type
    when "english"
      unless bid_increment.to_i >= MIN_BID_INCREMENT
        errors.add(:bid_increment, "must be at least #{MIN_BID_INCREMENT}")
      end
    when "dutch"
      dutch_fields_are_valid
    end
  end

  def dutch_fields_are_valid
    if floor_price.to_i < 1 || (start_price && floor_price.to_i >= start_price)
      errors.add(:floor_price, "must be at least 1 and below the starting price")
    end
    if price_drop.to_i < 1
      errors.add(:price_drop, "must be at least 1")
    elsif start_price && floor_price.to_i.positive? && price_drop > start_price - floor_price.to_i
      errors.add(:price_drop, "cannot be larger than the gap between starting and floor price")
    end
    unless DROP_INTERVAL_RANGE.cover?(drop_interval_minutes.to_i)
      errors.add(:drop_interval_minutes, "must be between #{DROP_INTERVAL_RANGE.first} and #{DROP_INTERVAL_RANGE.last} minutes")
    end
  end
end
