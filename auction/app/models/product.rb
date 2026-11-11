# Minimal stub of M2.1 (#18), extended with the catalog labels M3 needs.
class Product < ApplicationRecord
  # Category keys and labels from requirement/productOnboardingFlow.md (step 1).
  CATEGORIES = {
    "camera"      => "กล้อง",
    "watch"       => "นาฬิกา",
    "instrument"  => "เครื่องดนตรี",
    "it"          => "ไอที",
    "sports"      => "กีฬา",
    "collectible" => "ของสะสม",
    "furniture"   => "เฟอร์นิเจอร์",
    "art"         => "ศิลปะ",
    "vehicle"     => "ยานพาหนะ",
    "other"       => "อื่นๆ"
  }.freeze

  # Placeholder cover until product photos (M2.1 / M2.3) exist.
  CATEGORY_EMOJI = {
    "camera" => "📷", "watch" => "⌚", "instrument" => "🎸", "it" => "💻", "sports" => "🚲",
    "collectible" => "🏺", "furniture" => "🪑", "art" => "🖼️", "vehicle" => "🏍️", "other" => "📦"
  }.freeze

  CONDITIONS = {
    "new"       => "ใหม่",
    "like_new"  => "เหมือนใหม่",
    "good"      => "สภาพดี",
    "fair"      => "พอใช้",
    "for_parts" => "สำหรับซ่อม / อะไหล่"
  }.freeze

  # Statuses whose auction must not be shown in the public catalog.
  # in_event, sold, unsold and available-after-an-auction are public.
  PRIVATE_STATUSES = %w[draft pending_review rejected withdrawn].freeze

  belongs_to :seller, class_name: "User"
  has_one :auction, dependent: :destroy

  validates :code, presence: true, uniqueness: true
  validates :name, presence: true

  def category_label = CATEGORIES.fetch(category, category)
  def condition_label = CONDITIONS.fetch(condition, condition)
  def emoji = CATEGORY_EMOJI.fetch(category, "📦")
end
