require "test_helper"

class ThaiPhoneValidatorTest < ActiveSupport::TestCase
  class Subject
    include ActiveModel::Validations
    attr_accessor :phone
    validates :phone, thai_phone: true

    def initialize(phone) = @phone = phone
  end

  test "accepts 10 digits starting with 06, 08 or 09" do
    %w[0612345678 0812345678 0912345678].each { |p| assert Subject.new(p).valid?, p }
  end

  test "rejects other prefixes, lengths and characters" do
    %w[0212345678 0712345678 081234567 08123456789 08123456a8].each do |p|
      assert_not Subject.new(p).valid?, p
    end
  end
end
