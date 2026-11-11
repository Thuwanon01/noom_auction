require "test_helper"

class OnboardingStep1Test < ActionDispatch::IntegrationTest
  ID = "1234567890121"
  PHONE = "0898887777"

  setup do
    @user = users(:fresh)
    sign_in_as @user
  end

  def send_otp(id: ID, phone: PHONE)
    post onboarding_otp_path, params: { user: { national_id: id, phone: phone } }
  end

  def verify(code, phone: PHONE)
    post verify_onboarding_otp_path, params: { user: { national_id: ID, phone: phone }, otp_code: code }
  end

  def next_step(consent: "1", id: ID, phone: PHONE)
    post onboarding_step_path(1), params: { user: { national_id: id, phone: phone, pdpa_consent: consent } }
  end

  test "happy path: send OTP, verify, accept PDPA, next" do
    send_otp
    assert_redirected_to onboarding_step_path(1)
    assert_equal "OTP sent to 08X-XXX-7777", flash[:notice]

    verify OtpAdapters::Mock.last_code_for(PHONE)
    assert_redirected_to onboarding_step_path(1)
    assert @user.reload.phone_verified?

    next_step
    assert_redirected_to onboarding_step_path(2)
    @user.reload
    assert_equal "step1", @user.onboarding_status
    assert_equal ID, @user.national_id
    assert @user.pdpa_consented?
  end

  test "send OTP saves the draft so leaving and coming back keeps it" do
    send_otp
    get onboarding_step_path(1)
    assert_select "input[name='user[national_id]'][value=?]", ID
    assert_select "input[name='user[phone]'][value=?]", PHONE
  end

  test "invalid ID is rejected with the spec message and no OTP is sent" do
    assert_no_difference -> { OtpChallenge.count } do
      send_otp id: "1234567890122"
    end
    assert_response :unprocessable_entity
    assert_select ".field__error", text: "Invalid ID number"
  end

  test "an ID already registered is rejected" do
    send_otp id: users(:completed).national_id
    assert_response :unprocessable_entity
    assert_select ".field__error", text: "This ID is already registered"
  end

  test "a phone already registered is rejected" do
    send_otp phone: users(:completed).phone
    assert_response :unprocessable_entity
    assert_select ".field__error", text: "This phone number is already registered"
  end

  test "wrong OTP shows attempts left" do
    send_otp
    right = OtpAdapters::Mock.last_code_for(PHONE)
    verify format("%06d", (right.to_i + 1) % 1_000_000)
    assert_response :unprocessable_entity
    assert_select ".field__error", text: "Wrong OTP (2 attempts left)"
    assert_not @user.reload.phone_verified?
  end

  test "Next is disabled until the phone is verified" do
    get onboarding_step_path(1)
    assert_select "button[disabled]", text: "ถัดไป"

    send_otp
    verify OtpAdapters::Mock.last_code_for(PHONE)
    get onboarding_step_path(1)
    assert_select "button:not([disabled])", text: "ถัดไป"
  end

  test "server rejects Next without OTP verification" do
    next_step
    assert_response :unprocessable_entity
    assert_select ".field__error", text: "Please verify your phone number with OTP"
    assert_equal "not_started", @user.reload.onboarding_status
  end

  test "server rejects Next without PDPA consent" do
    send_otp
    verify OtpAdapters::Mock.last_code_for(PHONE)
    next_step consent: "0"
    assert_response :unprocessable_entity
    assert_select ".field__error", text: "Please accept the PDPA consent to continue"
    assert_equal "not_started", @user.reload.onboarding_status
  end

  test "changing the phone after verifying needs a new OTP" do
    send_otp
    verify OtpAdapters::Mock.last_code_for(PHONE)
    next_step phone: "0898887778"
    assert_response :unprocessable_entity
    assert_select ".field__error", text: "Please verify your phone number with OTP"
  end

  test "dashes and spaces in the ID and phone are accepted" do
    send_otp id: "1-2345-67890-12-1", phone: "089-888-7777"
    assert_redirected_to onboarding_step_path(1)
    assert_equal ID, @user.reload.national_id
    assert_equal PHONE, @user.phone
  end
end
