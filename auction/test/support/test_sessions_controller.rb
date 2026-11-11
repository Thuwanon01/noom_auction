# Test-only: puts a user in the session the way M1 login will.
class TestSessionsController < ApplicationController
  skip_forgery_protection

  def create
    session[:user_id] = params[:user_id]
    head :no_content
  end
end
