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

  # Deterministic so the unique index and uniqueness validation still work.
  encrypts :national_id, deterministic: true

  enum :onboarding_status, ONBOARDING_STATUSES.index_with(&:itself), default: "not_started", validate: true
  enum :occupation, OCCUPATIONS.keys.index_with(&:itself), prefix: true, validate: { allow_nil: true }

  validates :national_id, uniqueness: true, allow_nil: true
  validates :phone, uniqueness: true, allow_nil: true

  def occupation_label
    OCCUPATIONS[occupation]
  end
end
