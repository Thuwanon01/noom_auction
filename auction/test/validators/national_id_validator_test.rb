require "test_helper"

class NationalIdValidatorTest < ActiveSupport::TestCase
  class Subject
    include ActiveModel::Validations
    attr_accessor :national_id
    validates :national_id, national_id: true

    def initialize(id) = @national_id = id
  end

  VALID = %w[1101700203450 1234567890121 3100100123451 1999900001117].freeze

  test "accepts IDs with a correct checksum" do
    VALID.each { |id| assert Subject.new(id).valid?, id }
  end

  test "rejects a bad checksum" do
    %w[1101700203451 1234567890122 3100100123450].each do |id|
      assert_not Subject.new(id).valid?, id
    end
  end

  test "rejects the wrong length" do
    %w[110170020345 11017002034500 1].each { |id| assert_not Subject.new(id).valid?, id }
  end

  test "rejects non-digits and blanks" do
    [ "11017002034a0", "1101700 03450", "", nil ].each { |id| assert_not Subject.new(id).valid?, id.inspect }
  end

  test "uses the spec message" do
    subject = Subject.new("1101700203451")
    subject.valid?
    assert_equal [ "Invalid ID number" ], subject.errors[:national_id]
  end
end
