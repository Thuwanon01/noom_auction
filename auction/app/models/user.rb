class User < ApplicationRecord
  # Order matters: the wizard moves forward through these values.
  ONBOARDING_STATUSES = %w[not_started step1 step2 step3 completed].freeze

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

  # Deterministic so the unique index and uniqueness validation still work.
  encrypts :national_id, deterministic: true

  enum :onboarding_status, ONBOARDING_STATUSES.index_with(&:itself), default: "not_started", validate: true
  enum :occupation, OCCUPATIONS.keys.index_with(&:itself), prefix: true, validate: { allow_nil: true }

  validates :email, presence: true, uniqueness: true,
                    format: { with: URI::MailTo::EMAIL_REGEXP, allow_blank: true }
  validates :password, length: { minimum: 8 }, allow_nil: true
  validates :national_id, uniqueness: true, allow_nil: true
  validates :phone, uniqueness: true, allow_nil: true

  ONBOARDING_STEPS = 4

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

  def occupation_label
    OCCUPATIONS[occupation]
  end
end
