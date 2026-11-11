# M2.1 (#18) data + M2.2 (#19) lifecycle. Step validations (contexts :step1..:step3, :submit) are in
# Product::Wizard (M2.3+).
class Product < ApplicationRecord
  include ProductWizard

  class InvalidTransition < StandardError; end

  CATEGORIES = %w[camera watch musical_instrument it sports collectible furniture art vehicle other].freeze
  # Categories where the seller must upload proof of authenticity (M2.4).
  PROOF_REQUIRED_CATEGORIES = %w[collectible vehicle].freeze

  # draft -> pending_review -> available -> in_event -> pending_payment -> sold, with the side exits from the spec.
  # in_event -> available covers "unsold" (reserve not met / no bids). pending_payment is the 48-hour window after
  # an auction closes with a winner (M4.10/M4.11): paid -> sold, not paid -> back to available.
  TRANSITIONS = {
    "draft"           => %w[pending_review],
    "pending_review"  => %w[available rejected],
    "rejected"        => %w[pending_review],
    "available"       => %w[in_event withdrawn],
    "in_event"        => %w[pending_payment available],
    "pending_payment" => %w[sold available],
    "sold"            => [],
    "withdrawn"       => []
  }.freeze

  STATUS_LABELS = {
    "draft" => "แบบร่าง", "pending_review" => "รอตรวจสอบ", "rejected" => "ไม่ผ่าน",
    "available" => "พร้อมประมูล", "in_event" => "อยู่ในอีเวนต์", "pending_payment" => "รอชำระเงิน", "sold" => "ขายแล้ว", "withdrawn" => "ถอนออกแล้ว"
  }.freeze

  CATEGORY_LABELS = {
    "camera" => "กล้อง", "watch" => "นาฬิกา", "musical_instrument" => "เครื่องดนตรี", "it" => "ไอที",
    "sports" => "กีฬา", "collectible" => "ของสะสม", "furniture" => "เฟอร์นิเจอร์", "art" => "ศิลปะ",
    "vehicle" => "ยานพาหนะ", "other" => "อื่นๆ"
  }.freeze

  CONDITION_LABELS = {
    "new" => "ใหม่", "like_new" => "เหมือนใหม่", "good" => "สภาพดี", "fair" => "พอใช้", "for_parts" => "สำหรับอะไหล่"
  }.freeze

  # Placeholder cover until the catalog shows the product photos (M3 uses a category emoji).
  CATEGORY_EMOJI = {
    "camera" => "📷", "watch" => "⌚", "musical_instrument" => "🎸", "it" => "💻", "sports" => "🚲",
    "collectible" => "🏺", "furniture" => "🪑", "art" => "🖼️", "vehicle" => "🏍️", "other" => "📦"
  }.freeze

  # Statuses whose auction must not be shown in the public catalog (M3). Everything from in_event on is public.
  PRIVATE_STATUSES = %w[draft pending_review rejected withdrawn].freeze

  # Statuses where the seller may still edit the listing.
  EDITABLE_STATUSES = %w[draft rejected].freeze

  enum :category, CATEGORIES.index_by(&:itself)
  enum :condition, %w[new like_new good fair for_parts].index_by(&:itself), prefix: true
  enum :status, TRANSITIONS.keys.index_by(&:itself), default: "draft"

  belongs_to :seller, class_name: "User"
  has_one :auction, dependent: :destroy
  has_many :product_images, dependent: :destroy
  has_many :product_documents, dependent: :destroy

  before_validation :assign_code, if: :new_record?
  validates :code, presence: true, uniqueness: true
  validates :name, presence: true
  validate :locked_while_in_event, on: :update
  before_destroy :prevent_destroy_while_in_event, prepend: true

  # --- Next product code: P-0001, P-0002, ... --------------------------------------------------
  def self.next_code
    last = maximum(Arel.sql("CAST(SUBSTR(code, 3) AS INTEGER)")).to_i
    format("P-%04d", last + 1)
  end

  # Two sellers saving at the same moment can compute the same code; validation passes for both and the
  # unique index rejects the second insert. Recompute the code and retry (only for codes we generated
  # ourselves). The savepoint keeps the outer transaction usable on databases that abort it on error.
  def _create_record(*)
    attempts = 0
    begin
      self.class.transaction(requires_new: true) { super }
    rescue ActiveRecord::RecordNotUnique
      raise unless @generated_code && (attempts += 1) < 5

      self.code = self.class.next_code
      retry
    end
  end

  # --- Lifecycle -------------------------------------------------------------------------------
  def can_transition_to?(to) = TRANSITIONS.fetch(status, []).include?(to.to_s)

  def transition_to!(to, **attrs)
    to = to.to_s
    raise InvalidTransition, "#{status} -> #{to}" unless can_transition_to?(to)

    update!(status: to, **attrs)
  end

  def submit!        = transition_to!(:pending_review, rejection_reason: nil)
  def approve!       = transition_to!(:available)
  def reject!(reason)
    raise ArgumentError, "reason is required" if reason.blank?

    transition_to!(:rejected, rejection_reason: reason)
  end
  def withdraw!      = transition_to!(:withdrawn)
  def start_event!   = transition_to!(:in_event)
  def await_payment! = transition_to!(:pending_payment)
  def mark_sold!     = transition_to!(:sold)
  def return_to_available! = transition_to!(:available)

  def editable? = EDITABLE_STATUSES.include?(status)
  def status_label   = STATUS_LABELS[status]
  def category_label = CATEGORY_LABELS[category]
  def condition_label = CONDITION_LABELS[condition]

  def emoji = CATEGORY_EMOJI.fetch(category, "📦")

  def proof_required?
    PROOF_REQUIRED_CATEGORIES.include?(category)
  end

  private

  def assign_code
    return if code.present?

    self.code = self.class.next_code
    @generated_code = true
  end

  # An in_event product may change status (sold / back to available) but nothing else.
  def locked_while_in_event
    return unless status_was == "in_event"
    return if (changed - %w[status updated_at]).empty?

    errors.add(:base, "Cannot edit a product that is in an event")
  end

  def prevent_destroy_while_in_event
    return unless in_event?

    errors.add(:base, "Cannot delete a product that is in an event")
    throw :abort
  end
end
