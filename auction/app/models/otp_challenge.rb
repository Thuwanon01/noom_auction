# One OTP sent to one phone. Only the latest challenge for a phone counts.
class OtpChallenge < ApplicationRecord
  scope :for_phone, ->(phone) { where(phone: phone) }

  def self.latest_for(phone)
    for_phone(phone).order(created_at: :desc, id: :desc).first
  end

  def expired?(now = Time.current)
    expires_at <= now
  end

  def verified?
    verified_at.present?
  end
end
