# Idempotent local dev data. Run with `bin/rails db:seed`.
return unless Rails.env.development?

# Both accounts use the password "password123".
User.find_or_create_by!(email: "done@example.com") do |u|
  u.password = "password123"
  u.phone = "0812345678"
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

User.find_or_create_by!(email: "new@example.com") do |u|
  u.password = "password123"
end
