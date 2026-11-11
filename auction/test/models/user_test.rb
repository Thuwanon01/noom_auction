require "test_helper"

class UserTest < ActiveSupport::TestCase
  test "onboarding_status defaults to not_started" do
    assert_equal "not_started", User.new.onboarding_status
  end

  test "onboarding_status has the five spec values in order" do
    assert_equal %w[not_started step1 step2 step3 completed], User.onboarding_statuses.keys
  end

  test "rejects an unknown onboarding_status" do
    user = User.new(onboarding_status: "step9")
    assert_not user.valid?
    assert user.errors.of_kind?(:onboarding_status, :inclusion)
  end

  test "occupation has the six spec options" do
    assert_equal %w[government private_employee business_owner freelance student_unemployed other],
                 User.occupations.keys
  end

  test "rejects an unknown occupation" do
    user = User.new(occupation: "astronaut")
    assert_not user.valid?
    assert user.errors.of_kind?(:occupation, :inclusion)
  end

  test "national_id must be unique" do
    dup = User.new(national_id: users(:completed).national_id)
    assert_not dup.valid?
    assert dup.errors.of_kind?(:national_id, :taken)
  end

  test "phone must be unique" do
    dup = User.new(phone: users(:completed).phone)
    assert_not dup.valid?
    assert dup.errors.of_kind?(:phone, :taken)
  end

  test "national_id is encrypted at rest and still queryable" do
    raw = User.connection.select_value(
      User.where(id: users(:completed).id).select(:national_id).to_sql
    )
    assert_not_includes raw, "1101700203450"
    assert_equal users(:completed), User.find_by(national_id: "1101700203450")
  end
end
