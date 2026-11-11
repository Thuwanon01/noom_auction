require "test_helper"

class OnboardingStep3Test < ActionDispatch::IntegrationTest
  setup do
    @user = users(:fresh)
    @user.update_columns(onboarding_status: "step2", occupation: "government",
                         annual_income: 700_000, years_experience: 4)
    sign_in_as @user
  end

  test "shows the calculating state" do
    get onboarding_step_path(3)
    assert_response :success
    assert_select ".scoring__title", text: "Calculating your score…"
    assert_select "form[data-controller='auto-submit']"
  end

  test "scores on the server and moves to step 4" do
    assert_difference -> { @user.credit_scores.count }, 1 do
      post onboarding_step_path(3)
    end
    assert_redirected_to onboarding_step_path(4)
    @user.reload
    assert_equal "step3", @user.onboarding_status
    assert_equal 300 + 150 + 210 + 100, @user.credit_score
    assert_equal "A", @user.credit_grade
  end

  test "a score sent by the client is ignored" do
    @user.update_columns(occupation: "student_unemployed", annual_income: 1, years_experience: 0)
    post onboarding_step_path(3), params: { credit_score: 850, credit_grade: "A",
                                            user: { credit_score: 850, credit_grade: "A" } }
    @user.reload
    assert_equal 370, @user.credit_score
    assert_equal "D", @user.credit_grade
  end

  test "a scorer error shows Retry and loses no input" do
    with_stubbed(CreditScoring, :call, ->(**) { raise "scorer down" }) do
      assert_no_difference -> { CreditScore.count } do
        post onboarding_step_path(3)
      end
    end
    assert_response :unprocessable_entity
    assert_select ".scoring--error", text: /Something went wrong/
    assert_select "button", text: "Retry"

    @user.reload
    assert_equal "step2", @user.onboarding_status
    assert_equal [ "government", 700_000, 4 ], [ @user.occupation, @user.annual_income, @user.years_experience ]

    post onboarding_step_path(3)
    assert_redirected_to onboarding_step_path(4)
  end

  test "a timeout is handled like an error" do
    with_stubbed(CreditScoring, :call, ->(**) { raise Timeout::Error }) do
      post onboarding_step_path(3)
    end
    assert_response :unprocessable_entity
    assert_select ".scoring--error"
  end

  test "editing step 2 after scoring sends the user through scoring again" do
    post onboarding_step_path(3)
    post onboarding_step_path(2), params: { user: { occupation: "freelance", annual_income: "50,000", years_experience: "0" } }
    assert_redirected_to onboarding_step_path(3)
    assert_equal "step2", @user.reload.onboarding_status

    get onboarding_step_path(4)
    assert_redirected_to onboarding_step_path(3)

    post onboarding_step_path(3)
    assert_equal 300 + 90 + 30 + 0, @user.reload.credit_score
  end
end
