# Thai mobile number: 10 digits starting with 06, 08 or 09.
#
#   validates :phone, thai_phone: true
class ThaiPhoneValidator < ActiveModel::EachValidator
  MESSAGE = "Invalid phone number".freeze
  FORMAT = /\A0[689]\d{8}\z/

  def validate_each(record, attribute, value)
    record.errors.add(attribute, :invalid, message: options[:message] || MESSAGE) unless value.to_s.match?(FORMAT)
  end
end
