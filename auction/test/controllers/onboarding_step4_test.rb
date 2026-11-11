require "test_helper"

class OnboardingStep4Test < ActionDispatch::IntegrationTest
  ID = "1234567890121"
  PHONE = "0898887777"

  setup do
    @user = users(:fresh)
    @user.update!(national_id: ID, phone: PHONE, phone_verified_at: Time.current, pdpa_consented_at: Time.current,
                  occupation: "private_employee", annual_income: 480_000, years_experience: 4,
                  onboarding_status: "step2")
    sign_in_as @user
    post onboarding_step_path(3)
    assert_redirected_to onboarding_step_path(4)
  end

  test "shows the score, grade and breakdown" do
    get onboarding_step_path(4)
    assert_select ".gauge__score", text: "670"
    assert_select ".result__grade", text: /B: Good/
    assert_select ".breakdown summary", text: "How we calculated this"
    assert_select ".breakdown dd", text: "+120"
    assert_select ".breakdown dd", text: "+150"
    assert_select ".breakdown dd", text: "+100"
  end

  test "summary is masked and the full ID and phone never appear in the HTML" do
    get onboarding_step_path(4)
    assert_select ".summary dd", text: "1-2345-XXXXX-XX-1"
    assert_select ".summary dd", text: "08X-XXX-7777"
    assert_not_includes response.body, ID
    assert_not_includes response.body, PHONE
    assert_not_includes response.body, "098887777" # any long run of the phone digits
  end

  test "each summary item links back to its step" do
    get onboarding_step_path(4)
    assert_select ".summary__edit a[href=?]", onboarding_step_path(1), 2
    assert_select ".summary__edit a[href=?]", onboarding_step_path(2), 3
  end

  test "Back returns to step 2" do
    get onboarding_step_path(4)
    assert_select ".form__actions a[href=?]", onboarding_step_path(2), text: "ย้อนกลับ"
  end

  test "confirm without the checkbox is rejected on the server" do
    post onboarding_step_path(4), params: { user: { confirm_truth: "0" } }
    assert_response :unprocessable_entity
    assert_select ".field__error", text: "Please confirm that the information is true"
    @user.reload
    assert_equal "step3", @user.onboarding_status
    assert_nil @user.confirmed_at
  end

  test "confirm completes onboarding and goes to the auction home page" do
    post onboarding_step_path(4), params: { user: { confirm_truth: "1" } }
    assert_redirected_to auctions_path
    @user.reload
    assert_equal "completed", @user.onboarding_status
    assert_not_nil @user.confirmed_at

    get onboarding_path
    assert_redirected_to auctions_path
  end

  test "editing from step 4 re-runs scoring" do
    post onboarding_step_path(2), params: { user: { occupation: "government", annual_income: "480,000", years_experience: "4" } }
    assert_redirected_to onboarding_step_path(3)
    post onboarding_step_path(3)
    get onboarding_step_path(4)
    assert_select ".gauge__score", text: "700"
  end
end
