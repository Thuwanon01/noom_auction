require "test_helper"

class OnboardingStep2Test < ActionDispatch::IntegrationTest
  setup do
    @user = users(:fresh)
    @user.update_columns(national_id: nil, onboarding_status: "step1")
    sign_in_as @user
  end

  def submit(**attrs)
    post onboarding_step_path(2), params: {
      user: { occupation: "business_owner", annual_income: "1,250,000", years_experience: "3.5" }.merge(attrs)
    }
  end

  test "Next saves the draft and moves to step 3" do
    submit
    assert_redirected_to onboarding_step_path(3)
    @user.reload
    assert_equal "step2", @user.onboarding_status
    assert_equal "business_owner", @user.occupation
    assert_equal 1_250_000, @user.annual_income
    assert_equal 3.5, @user.years_experience
  end

  test "invalid input re-renders with errors and keeps the status" do
    submit annual_income: "0"
    assert_response :unprocessable_entity
    assert_select ".field__error", text: /Annual income must be more than 0/
    assert_equal "step1", @user.reload.onboarding_status
  end

  test "form shows the hint and the six occupations" do
    get onboarding_step_path(2)
    assert_select ".field__hint", text: "Total income before tax, from all sources"
    assert_select "select[name='user[occupation]'] option[value]:not([value=''])", 6
  end

  test "coming back shows the saved values with a thousands separator" do
    submit
    get onboarding_step_path(2)
    assert_select "input[name='user[annual_income]'][value='1,250,000']"
    assert_select "option[selected][value='business_owner']"
  end

  test "Back keeps the Step 1 data" do
    @user.update_columns(phone: "0898887777", phone_verified_at: Time.current, pdpa_consented_at: Time.current)
    submit
    get onboarding_step_path(1)
    assert_select "input[name='user[phone]'][value='0898887777']"
    assert_select ".otp-ok"
  end

  test "the score cannot be set from this form" do
    submit credit_score: 850, credit_grade: "A", onboarding_status: "completed"
    @user.reload
    assert_nil @user.credit_score
    assert_equal "step2", @user.onboarding_status
  end
end
