# Minimal stub of M2.1 (#18) for the bidding flow.
class Product < ApplicationRecord
  belongs_to :seller, class_name: "User"
  has_one :auction, dependent: :destroy

  validates :code, presence: true, uniqueness: true
  validates :name, presence: true
end
