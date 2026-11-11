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

  before_action :require_login
  before_action :redirect_completed_user
  before_action :set_step, only: %i[show update]
  before_action :guard_step, only: %i[show update]

  def index
    redirect_to onboarding_step_path(current_user.onboarding_step_reached)
  end

  def show
    render "step#{@step}"
  end

  def update
    send("update_step#{@step}")
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

  def finish_step(step)
    @user.onboarding_status = User.status_after_step(step)
  end

  def go_to_next_step
    redirect_to onboarding_step_path(@step + 1)
  end

  # --- Per-step handlers. Each one is filled in by its own issue. ---

  def update_step1
    finish_step(1)
    @user.save!
    go_to_next_step
  end

  def update_step2
    finish_step(2)
    @user.save!
    go_to_next_step
  end

  def update_step3
    finish_step(3)
    @user.save!
    go_to_next_step
  end

  def update_step4
    finish_step(4)
    @user.confirmed_at = Time.current
    @user.save!
    redirect_to auctions_path
  end
end
