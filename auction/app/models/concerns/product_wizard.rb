# Validation contexts for the 4-step seller wizard (productOnboardingFlow.md).
#   :step1  product info          :step2  photos and proof
#   :step3  auction setup         :submit all of the above plus the seller terms
module ProductWizard
  extend ActiveSupport::Concern

  STEPS = { 1 => :step1, 2 => :step2, 3 => :step3 }.freeze
  MAX_IMAGES = 8

  included do
    attr_accessor :accept_terms

    validates :name, length: { in: 5..100 }, on: %i[step1 submit]
    validates :category, :condition, presence: true, on: %i[step1 submit]
    validates :description, length: { in: 20..2000 }, on: %i[step1 submit]
    validates :brand, :model, length: { maximum: 100 }, allow_blank: true, on: %i[step1 submit]
    validates :year, numericality: { only_integer: true, greater_than: 0, less_than_or_equal_to: 2100 },
                     allow_nil: true, on: %i[step1 submit]
    # Minimal completeness rules so later steps cannot be opened early; M2.4/M2.5 add the detailed ones.
    validate :needs_photo, :needs_proof, on: %i[step2 submit]
    validate :needs_auction, on: %i[step3 submit]
  end

  # Is this step's data complete? Used to stop the wizard URL jumping ahead of the saved data.
  def step_complete?(step)
    context = STEPS[step.to_i]
    return false unless context

    valid?(context)
  end

  # The first step whose data is missing, or 4 when steps 1-3 are done.
  def next_incomplete_step
    (1..3).find { |s| !step_complete?(s) } || 4
  end

  def can_open_step?(step) = step.to_i <= next_incomplete_step

  private

  def needs_photo
    errors.add(:base, "Add at least 1 photo") if product_images.none?
  end

  def needs_proof
    return unless proof_required? && product_documents.none?

    errors.add(:base, "Proof of authenticity is required for #{category_label}")
  end

  def needs_auction
    errors.add(:base, "Set up the auction") if auction.blank?
  end
end
