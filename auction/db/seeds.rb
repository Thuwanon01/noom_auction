# Idempotent local dev data. Run with `bin/rails db:seed`.
return unless Rails.env.development?

User.find_or_create_by!(phone: "0812345678") do |u|
  u.national_id = "1101700203450"
  u.phone_verified_at = Time.current
  u.pdpa_consented_at = Time.current
  u.occupation = "private_employee"
  u.annual_income = 480_000
  u.years_experience = 4
  u.credit_score = 670
  u.credit_grade = "B"
  u.score_model_version = "v1-draft"
  u.confirmed_at = Time.current
  u.onboarding_status = "completed"
end

User.find_or_create_by!(phone: "0898765432")
