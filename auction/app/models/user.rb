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
  has_many :credit_scores, dependent: :destroy
  # M2 / M4: products a user sells and bids a user places.
  has_many :products, foreign_key: :seller_id, inverse_of: :seller, dependent: :restrict_with_exception
  has_many :bids, dependent: :restrict_with_exception
  has_many :notifications, dependent: :destroy

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
  validates :name, length: { maximum: 100 }

  # Step 1: identity
  attribute :pdpa_consent, :boolean

  validates :national_id, national_id: true, uniqueness: { message: "This ID is already registered" }, allow_nil: true
  validates :phone, thai_phone: true, uniqueness: { message: "This phone number is already registered" }, allow_nil: true
  validates :phone, presence: { message: "Enter your phone number" }, on: %i[step1 otp_request]
  validates :national_id, presence: { message: "Enter your national ID number" }, on: :step1
  validate :phone_must_be_verified, on: :step1
  validate :pdpa_must_be_accepted, on: :step1

  # Step 2: financial profile
  MAX_ANNUAL_INCOME = 100_000_000
  MAX_YEARS_EXPERIENCE = 50
  MIN_WORKING_AGE = 15 # Thai Labour Protection Act minimum employment age

  validates :occupation, presence: { message: "Select your occupation" }, on: :step2
  validates :annual_income, presence: { message: "Enter your annual income" }, on: :step2
  validates :annual_income, allow_nil: true, numericality: {
    greater_than: 0, less_than_or_equal_to: MAX_ANNUAL_INCOME,
    message: "Annual income must be more than 0 and at most 100,000,000 THB"
  }
  validates :years_experience, presence: { message: "Enter your years of experience" }, on: :step2
  validates :years_experience, allow_nil: true, numericality: {
    greater_than_or_equal_to: 0, less_than_or_equal_to: MAX_YEARS_EXPERIENCE,
    message: "Years of experience must be between 0 and 50"
  }
  validate :experience_fits_age

  # Step 4: confirm
  attribute :confirm_truth, :boolean
  validate :truth_must_be_confirmed, on: :confirm
  validates :credit_score, :credit_grade, presence: true, on: :confirm

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

  # The form shows a thousands separator, e.g. "1,250,000".
  def annual_income=(value)
    super(value.is_a?(String) ? value.delete(",").strip : value)
  end

  def age(on: Date.current)
    return nil unless birth_date

    (on.strftime("%Y%m%d").to_i - birth_date.strftime("%Y%m%d").to_i) / 10_000
  end

  # Logged-in pages that need a finished profile use OnboardingGate#require_onboarded.
  def onboarded?
    completed?
  end

  # Shown to other users (seller, bid history). Registration does not ask for a name, so fall back to the part
  # of the email before the @.
  def display_name
    name.presence || email.to_s.split("@").first
  end

  def latest_credit_score
    credit_scores.order(:created_at, :id).last
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

  # Only checked when a birth date is known; skipped silently otherwise.
  def experience_fits_age
    return if age.nil? || years_experience.nil? || errors.include?(:years_experience)
    return if years_experience <= [ age - MIN_WORKING_AGE, 0 ].max

    errors.add(:years_experience, :too_long, message: "Years of experience does not match your age")
  end

  def truth_must_be_confirmed
    errors.add(:confirm_truth, :accepted, message: "Please confirm that the information is true") unless confirm_truth
  end

  def reset_phone_verification
    self.phone_verified_at = nil
  end
end
