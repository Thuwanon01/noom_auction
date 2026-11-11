# Development/test only helper to sign in as a seeded user until M1.2 (#8) ships real login.
class DevSessionsController < ApplicationController
  def create
    session[:user_id] = User.find(params[:user_id]).id
    redirect_to params[:return_to].presence || root_path
  end
end
