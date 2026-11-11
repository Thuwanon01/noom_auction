require "test_helper"

class UserFinancialProfileTest < ActiveSupport::TestCase
  def profile(**attrs)
    users(:fresh).tap do |u|
      u.assign_attributes({ occupation: "private_employee", annual_income: "360,000", years_experience: "1.5" }.merge(attrs))
    end
  end

  def errors_for(attribute, **attrs)
    user = profile(**attrs)
    user.valid?(:step2)
    user.errors[attribute]
  end

  test "a complete profile is valid" do
    assert profile.valid?(:step2)
  end

  test "annual income accepts a thousands separator" do
    assert_equal 1_250_000, profile(annual_income: "1,250,000").annual_income
  end

  test "occupation is required" do
    assert_equal [ "Select your occupation" ], errors_for(:occupation, occupation: nil)
  end

  test "occupation must be one of the six options" do
    assert_not_empty errors_for(:occupation, occupation: "astronaut")
  end

  test "annual income is required" do
    assert_includes errors_for(:annual_income, annual_income: ""), "Enter your annual income"
  end

  test "annual income must be more than 0" do
    assert_not_empty errors_for(:annual_income, annual_income: "0")
    assert_not_empty errors_for(:annual_income, annual_income: "-5")
  end

  test "annual income is at most 100,000,000" do
    assert_empty errors_for(:annual_income, annual_income: "100,000,000")
    assert_not_empty errors_for(:annual_income, annual_income: "100,000,001")
  end

  test "annual income must be a number" do
    assert_not_empty errors_for(:annual_income, annual_income: "lots")
  end

  test "years of experience is required" do
    assert_includes errors_for(:years_experience, years_experience: ""), "Enter your years of experience"
  end

  test "years of experience is 0 to 50, decimals allowed" do
    assert_empty errors_for(:years_experience, years_experience: "0")
    assert_empty errors_for(:years_experience, years_experience: "1.5")
    assert_empty errors_for(:years_experience, years_experience: "50")
    assert_not_empty errors_for(:years_experience, years_experience: "50.5")
    assert_not_empty errors_for(:years_experience, years_experience: "-1")
  end

  test "experience must fit the age when a birth date is known" do
    travel_to Date.new(2026, 11, 11) do
      twenty = Date.new(2006, 11, 11)
      assert_empty errors_for(:years_experience, birth_date: twenty, years_experience: "5")
      assert_equal [ "Years of experience does not match your age" ],
                   errors_for(:years_experience, birth_date: twenty, years_experience: "6")
    end
  end

  test "age check is skipped when the birth date is unknown" do
    assert_empty errors_for(:years_experience, birth_date: nil, years_experience: "50")
  end
end
