# In-app notification. The text is derived from kind + auction, so wording
# can change without migrating stored rows. Email is out of scope.
class Notification < ApplicationRecord
  KINDS = %w[outbid won lost seller_sold seller_no_winner seller_unsold].freeze

  enum :kind, KINDS.index_by(&:itself)

  belongs_to :user
  belongs_to :auction, optional: true # later kinds (e.g. product review in M2.8) may not have one

  scope :unread, -> { where(read_at: nil) }
  scope :newest_first, -> { order(created_at: :desc, id: :desc) }

  def mark_read!(now = Time.current)
    update!(read_at: now) unless read_at
  end

  def message
    name = auction&.product&.name
    price = auction && "฿#{auction.current_price.to_fs(:delimited)}"
    case kind
    when "outbid" then "You were outbid on #{name}"
    when "won" then "You won #{name} for #{price}. Please pay within 48 hours"
    when "lost" then "Auction ended. You did not win"
    when "seller_sold" then "#{name} sold for #{price}"
    when "seller_no_winner" then "#{name} ended below the reserve price. No winner"
    when "seller_unsold" then "#{name} ended with no bids"
    end
  end
end
