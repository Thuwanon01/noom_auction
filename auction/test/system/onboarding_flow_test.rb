require "application_system_test_case"

class OnboardingFlowTest < ApplicationSystemTestCase
  ID = "3100100123451"
  PHONE = "0612223333"

  def register(email = "e2e@example.com")
    visit register_path
    fill_in "Email", with: email
    fill_in "user_password", with: "password123"
    fill_in "user_password_confirmation", with: "password123"
    click_on "สมัครสมาชิก"
  end

  def complete_step1
    assert_text "ขั้นที่ 1/4"
    fill_in "เลขบัตรประจำตัวประชาชน", with: ID
    fill_in "เบอร์มือถือ", with: PHONE
    click_on "ส่ง OTP"
    assert_text "OTP sent to 06X-XXX-3333"

    fill_in "รหัส OTP", with: OtpAdapters::Mock.last_code_for(PHONE)
    click_on "ยืนยัน OTP"
    assert_text "Phone number verified"

    check "user_pdpa_consent"
    click_on "ถัดไป"
  end

  def complete_step2(income: "720,000")
    assert_text "ขั้นที่ 2/4"
    select "Government/State enterprise", from: "อาชีพ"
    fill_in "รายได้ต่อปี (บาท)", with: income
    fill_in "ประสบการณ์ทำงาน (ปี)", with: "6.5"
    click_on "ถัดไป"
  end

  test "register, all four steps, confirm, land on the auction list" do
    register
    complete_step1
    complete_step2

    assert_text "Calculating your score…"
    click_on "คำนวณคะแนน" # the auto-submit fallback without JavaScript

    assert_text "ขั้นที่ 4/4"
    assert_selector ".gauge__score", text: "790" # 300 + 150 + 210 + 130
    assert_text "A: Excellent"
    assert_text "3-1001-XXXXX-XX-1"
    assert_text "06X-XXX-3333"
    assert_no_text ID

    check "user_confirm_truth"
    click_on "ยืนยัน"

    assert_current_path auctions_path
    assert_text "Your profile is complete"
    user = User.find_by!(email: "e2e@example.com")
    assert user.onboarded?
    assert_equal 790, user.credit_score
  end

  test "leave at step 2 and resume there with step 1 kept" do
    register
    complete_step1
    assert_text "ขั้นที่ 2/4"

    find(".wizard__logout").click
    visit login_path
    fill_in "Email", with: "e2e@example.com"
    fill_in "password", with: "password123"
    click_on "Login"

    assert_current_path onboarding_step_path(2)
    click_on "ย้อนกลับ"
    assert_field "เลขบัตรประจำตัวประชาชน", with: ID
    assert_text "ยืนยันเบอร์ 06X-XXX-3333 แล้ว"
  end

  test "scoring fails, then Retry works" do
    register
    complete_step1
    complete_step2

    with_stubbed(CreditScoring, :call, ->(**) { raise "scorer down" }) do
      click_on "คำนวณคะแนน"
      assert_text "Something went wrong"
    end

    click_on "Retry"
    assert_text "ขั้นที่ 4/4"
    assert_selector ".gauge__score", text: "790"
  end

  test "edit from step 4 re-runs scoring" do
    register
    complete_step1
    complete_step2
    click_on "คำนวณคะแนน"
    assert_selector ".gauge__score", text: "790"

    all(".summary__edit a").last.click # years of experience → step 2
    fill_in "รายได้ต่อปี (บาท)", with: "100,000"
    click_on "ถัดไป"
    click_on "คำนวณคะแนน"
    assert_selector ".gauge__score", text: "610" # 300 + 150 + 30 + 130
    assert_text "C: Fair"
  end
end
