# Thai national ID: 13 digits, the last one a checksum of the first 12.
#
#   validates :national_id, national_id: true
class NationalIdValidator < ActiveModel::EachValidator
  MESSAGE = "Invalid ID number".freeze

  def self.valid?(value)
    digits = value.to_s
    return false unless digits.match?(/\A\d{13}\z/)

    d = digits.chars.map(&:to_i)
    sum = (0..11).sum { |i| d[i] * (13 - i) }
    (11 - sum % 11) % 10 == d[12]
  end

  def validate_each(record, attribute, value)
    record.errors.add(attribute, :invalid, message: options[:message] || MESSAGE) unless self.class.valid?(value)
  end
end
