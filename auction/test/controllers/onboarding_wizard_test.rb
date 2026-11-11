require "test_helper"

class OnboardingWizardTest < ActionDispatch::IntegrationTest
  test "guests are sent to login" do
    get onboarding_path
    assert_redirected_to login_path
  end

  test "register sends the new user to step 1" do
    post register_path, params: { user: { email: "w@example.com", password: "password123",
                                           password_confirmation: "password123" } }
    assert_redirected_to onboarding_step_path(1)
  end

  test "/onboarding resumes at the step the user stopped at" do
    user = users(:fresh)
    sign_in_as user

    { "not_started" => 1, "step1" => 2, "step2" => 3, "step3" => 4 }.each do |status, step|
      user.update_column(:onboarding_status, status)
      get onboarding_path
      assert_redirected_to onboarding_step_path(step), "status #{status}"
    end
  end

  test "login sends an incomplete user to onboarding" do
    sign_in_as users(:fresh)
    assert_redirected_to onboarding_path
  end

  test "cannot jump ahead to a step whose earlier data is missing" do
    sign_in_as users(:fresh)
    get onboarding_step_path(3)
    assert_redirected_to onboarding_step_path(1)

    post onboarding_step_path(4)
    assert_redirected_to onboarding_step_path(1)
    assert_equal "not_started", users(:fresh).reload.onboarding_status
  end

  test "earlier steps stay open for editing" do
    users(:fresh).update_column(:onboarding_status, "step3")
    sign_in_as users(:fresh)
    get onboarding_step_path(1)
    assert_response :success
  end

  test "progress bar shows the current step" do
    sign_in_as users(:fresh)
    get onboarding_step_path(1)
    assert_select ".wizard__count", text: /1\/4/
    assert_select ".wizard__seg--on", 1
  end

  test "completed users are redirected to the auction home page" do
    sign_in_as users(:completed)
    get onboarding_path
    assert_redirected_to auctions_path
    get onboarding_step_path(2)
    assert_redirected_to auctions_path
  end
end
