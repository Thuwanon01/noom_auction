class Bid < ApplicationRecord
  belongs_to :auction
  belongs_to :user

  validates :amount, presence: true, numericality: { only_integer: true, greater_than: 0 }
  validates :idempotency_key, presence: true, uniqueness: { scope: %i[user_id auction_id] }

  before_validation { self.placed_at ||= Time.current }

  scope :ranked, -> { order(amount: :desc, placed_at: :asc) }
end
