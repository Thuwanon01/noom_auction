# The 4-step onboarding wizard: /onboarding/1 .. /onboarding/4.
#
# Each step saves its data on the user as a draft and moves
# onboarding_status forward, so a user who leaves can resume where they
# stopped (GET /onboarding). Steps after the one the user has reached are
# locked. See requirement/onboardingFlow.md.
class OnboardingController < ApplicationController
  STEP_TITLES = {
    1 => "ยืนยันตัวตน",
    2 => "ข้อมูลการเงิน",
    3 => "คำนวณคะแนนเครดิต",
    4 => "ผลลัพธ์และยืนยัน"
  }.freeze

  SCORING_TIMEOUT = 5.seconds

  before_action :require_login
  before_action :redirect_completed_user
  before_action :set_step, only: %i[show update]
  before_action :guard_step, only: %i[show update]
  before_action :set_step1, only: %i[send_otp verify_otp]

  rate_limit to: 10, within: 10.minutes, only: :send_otp,
             with: -> { redirect_to onboarding_step_path(1), alert: "Too many OTP requests. Try again later." }

  def index
    redirect_to onboarding_step_path(current_user.onboarding_step_reached)
  end

  def show
    render "step#{@step}"
  end

  def update
    send("update_step#{@step}")
  end

  # Step 1, "Send OTP": saves the ID and phone as a draft, then sends a code.
  def send_otp
    assign_identity
    return render_step1 unless @user.save(context: :otp_request)

    result = otp_service.send_code(@user.phone)
    if result.sent?
      redirect_to onboarding_step_path(1), notice: "OTP sent to #{helpers.mask_phone(@user.phone)}"
    else
      redirect_to onboarding_step_path(1), alert: result.message
    end
  end

  # Step 1, "Verify OTP": checks the code for the phone saved by send_otp.
  def verify_otp
    assign_identity
    if @user.phone_changed? || @user.phone.blank?
      @otp_error = "Send an OTP to this phone number first"
      return render_step1
    end

    result = otp_service.verify(@user.phone, params[:otp_code])
    unless result.ok?
      @otp_error = result.message
      return render_step1
    end

    @user.phone_verified_at = Time.current
    unless @user.save(context: :otp_request)
      # Keep the verification even if the ID typed next to it is not valid yet.
      @user.restore_attributes(%i[national_id])
      @user.save!(context: :otp_request)
    end
    redirect_to onboarding_step_path(1), notice: result.message
  end

  private

  def redirect_completed_user
    redirect_to auctions_path if current_user.completed?
  end

  def set_step
    @step = params[:step].to_i
    @user = current_user
  end

  # Block jumping ahead to a step whose earlier data is missing.
  def guard_step
    return if current_user.can_open_onboarding_step?(@step)

    redirect_to onboarding_step_path(current_user.onboarding_step_reached),
                alert: "Please finish this step first"
  end

  def set_step1
    @step = 1
    @user = current_user
  end

  def render_step1
    render :step1, status: :unprocessable_entity
  end

  # Shared by Send OTP, Verify OTP and Next, which all submit the same form.
  def assign_identity
    @user.assign_attributes(params.fetch(:user, {}).permit(:national_id, :phone, :pdpa_consent))
    return if @user.pdpa_consent.nil?

    @user.pdpa_consented_at = @user.pdpa_consent ? (@user.pdpa_consented_at || Time.current) : nil
  end

  def otp_service
    @otp_service ||= OtpService.new
  end

  def finish_step(step)
    @user.onboarding_status = User.status_after_step(step)
  end

  def go_to_next_step
    redirect_to onboarding_step_path(@step + 1)
  end

  # --- Per-step handlers. Each one is filled in by its own issue. ---

  def update_step1
    assign_identity
    finish_step(1)

    if @user.save(context: :step1)
      go_to_next_step
    else
      @user.restore_attributes(%i[onboarding_status pdpa_consented_at])
      render_step1
    end
  end

  def update_step2
    @user.assign_attributes(params.fetch(:user, {}).permit(:occupation, :annual_income, :years_experience))
    finish_step(2)

    if @user.save(context: :step2)
      go_to_next_step
    else
      @user.restore_attributes(%i[onboarding_status])
      render :step2, status: :unprocessable_entity
    end
  end

  # Scoring always runs here on the server from the saved Step 2 data. Nothing
  # in the request body is used, so a client cannot submit its own score.
  def update_step3
    result = Timeout.timeout(SCORING_TIMEOUT) { CreditScoring.score_for(@user) }
    @user.transaction do
      CreditScoring.record!(@user, result)
      finish_step(3)
      @user.save!
    end
    go_to_next_step
  rescue StandardError, Timeout::Error => e
    Rails.logger.error("[onboarding] credit scoring failed for user #{@user.id}: #{e.class}: #{e.message}")
    @user.reload
    @scoring_failed = true
    render :step3, status: :unprocessable_entity
  end

  def update_step4
    finish_step(4)
    @user.confirmed_at = Time.current
    @user.save!
    redirect_to auctions_path
  end
end
