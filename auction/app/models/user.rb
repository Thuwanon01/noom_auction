# Minimal stub of M1.1 (#7) for the bidding flow.
class User < ApplicationRecord
  enum :onboarding_status, %w[not_started step1 step2 step3 completed].index_by(&:itself), default: "not_started"

  has_many :products, foreign_key: :seller_id, inverse_of: :seller, dependent: :restrict_with_exception
  has_many :bids, dependent: :restrict_with_exception
  has_many :notifications, dependent: :destroy

  validates :name, presence: true
  validates :email, presence: true, uniqueness: true
end
