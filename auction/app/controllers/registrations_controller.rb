class RegistrationsController < ApplicationController
  def new
    return redirect_to auctions_path if logged_in?

    @user = User.new
  end

  def create
    @user = User.new(registration_params)

    if @user.save
      log_in(@user)
      redirect_to after_registration_path
    else
      render :new, status: :unprocessable_entity
    end
  end

  private

  def registration_params
    params.expect(user: %i[email password password_confirmation])
  end

  def after_registration_path
    auctions_path
  end
end
