class SessionsController < ApplicationController
  rate_limit to: 10, within: 3.minutes, only: :create,
             with: -> { redirect_to login_path, alert: "Too many attempts. Try again later." }

  def new
    redirect_to after_login_path if logged_in?
  end

  def create
    user = User.find_by(email: params[:email].to_s.strip.downcase)

    if user&.authenticate(params[:password].to_s)
      log_in(user)
      redirect_to pop_return_to || after_login_path
    else
      @email = params[:email]
      flash.now[:alert] = "Invalid email or password"
      render :new, status: :unprocessable_entity
    end
  end

  def destroy
    log_out
    redirect_to root_path, notice: "Logged out"
  end

  private

  def after_login_path
    current_user.onboarded? ? auctions_path : onboarding_path
  end
end
