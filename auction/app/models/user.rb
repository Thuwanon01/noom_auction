class User < ApplicationRecord
  # Order matters: the wizard moves forward through these values.
  ONBOARDING_STATUSES = %w[not_started step1 step2 step3 completed].freeze
  ONBOARDING_STEPS = 4

  OCCUPATIONS = {
    "government"         => "Government/State enterprise",
    "private_employee"   => "Private employee",
    "business_owner"     => "Business owner",
    "freelance"          => "Freelance/Professional",
    "student_unemployed" => "Student/Unemployed",
    "other"              => "Other"
  }.freeze

  has_secure_password

  normalizes :email, with: ->(email) { email.strip.downcase }
  # Users often type "1-2345-67890-12-3" or "081-234-5678".
  normalizes :national_id, :phone, with: ->(value) { value.to_s.gsub(/[\s-]/, "").presence }

  # Deterministic so the unique index and uniqueness validation still work.
  encrypts :national_id, deterministic: true

  enum :onboarding_status, ONBOARDING_STATUSES.index_with(&:itself), default: "not_started", validate: true
  enum :occupation, OCCUPATIONS.keys.index_with(&:itself), prefix: true, validate: { allow_nil: true }

  validates :email, presence: true, uniqueness: true,
                    format: { with: URI::MailTo::EMAIL_REGEXP, allow_blank: true }
  validates :password, length: { minimum: 8 }, allow_nil: true

  # Step 1: identity
  attribute :pdpa_consent, :boolean

  validates :national_id, national_id: true, uniqueness: { message: "This ID is already registered" }, allow_nil: true
  validates :phone, thai_phone: true, uniqueness: { message: "This phone number is already registered" }, allow_nil: true
  validates :phone, presence: { message: "Enter your phone number" }, on: %i[step1 otp_request]
  validates :national_id, presence: { message: "Enter your national ID number" }, on: :step1
  validate :phone_must_be_verified, on: :step1
  validate :pdpa_must_be_accepted, on: :step1

  # Changing the phone number means it has to be verified again.
  before_save :reset_phone_verification, if: -> { will_save_change_to_phone? && !will_save_change_to_phone_verified_at? }

  # The furthest wizard step this user may open. Earlier steps stay open so the
  # user can go back and edit. nil once onboarding is completed.
  def onboarding_step_reached
    return nil if completed?

    ONBOARDING_STATUSES.index(onboarding_status) + 1
  end

  def can_open_onboarding_step?(step)
    reached = onboarding_step_reached
    reached.present? && step.between?(1, reached)
  end

  # Status recorded after a step is submitted. Re-submitting an earlier step
  # moves the status back, so the later steps (and scoring) run again.
  def self.status_after_step(step)
    step == ONBOARDING_STEPS ? "completed" : "step#{step}"
  end

  def phone_verified?
    phone.present? && phone_verified_at.present? && !phone_changed?
  end

  def pdpa_consented?
    pdpa_consented_at.present?
  end

  def occupation_label
    OCCUPATIONS[occupation]
  end

  private

  def phone_must_be_verified
    return if phone.blank? || errors.include?(:phone)

    errors.add(:phone, :unverified, message: "Please verify your phone number with OTP") unless phone_verified?
  end

  def pdpa_must_be_accepted
    errors.add(:pdpa_consent, :accepted, message: "Please accept the PDPA consent to continue") unless pdpa_consent
  end

  def reset_phone_verification
    self.phone_verified_at = nil
  end
end
