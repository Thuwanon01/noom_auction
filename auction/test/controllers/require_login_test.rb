require "test_helper"

class RequireLoginTest < ActionDispatch::IntegrationTest
  class ProtectedController < ApplicationController
    before_action :require_login

    def show
      render plain: "secret for #{current_user.email}"
    end
  end

  test "guests are redirected to /login and sent back after logging in" do
    with_routing do |set|
      set.draw do
        get "protected", to: "require_login_test/protected#show"
        get "login", to: "sessions#new", as: :login
        post "login", to: "sessions#create"
        get "auctions", to: "auctions#index", as: :auctions
      end

      get "/protected"
      assert_redirected_to "/login"

      post "/login", params: { email: users(:fresh).email, password: "password123" }
      assert_redirected_to "/protected"

      get "/protected"
      assert_response :success
      assert_equal "secret for #{users(:fresh).email}", response.body
    end
  end
end
