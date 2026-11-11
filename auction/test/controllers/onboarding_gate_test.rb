require "test_helper"

class OnboardingGateTest < ActionDispatch::IntegrationTest
  class GatedController < ApplicationController
    before_action :require_onboarded

    def show
      render plain: "grade #{current_user.credit_grade}"
    end
  end

  def with_gated_route(&block)
    with_routing do |set|
      set.draw do
        get "gated", to: "onboarding_gate_test/gated#show"
        get "login", to: "sessions#new", as: :login
        post "login", to: "sessions#create"
        get "onboarding", to: "onboarding#index", as: :onboarding
        get "onboarding/:step", to: "onboarding#show", as: :onboarding_step
        get "auctions", to: "auctions#index", as: :auctions
      end
      block.call
    end
  end

  test "guest is sent to login" do
    with_gated_route do
      get "/gated"
      assert_redirected_to "/login"
    end
  end

  test "incomplete user is sent to their onboarding step with the message" do
    users(:fresh).update_columns(onboarding_status: "step2")
    with_gated_route do
      post "/login", params: { email: users(:fresh).email, password: "password123" }
      get "/gated"
      assert_redirected_to "/onboarding/3"
      assert_equal "Complete your profile to bid", flash[:alert]
    end
  end

  test "completed user gets through and can read the credit grade" do
    with_gated_route do
      post "/login", params: { email: users(:completed).email, password: "password123" }
      get "/gated"
      assert_response :success
      assert_equal "grade B", response.body
    end
  end

  test "User#onboarded? follows onboarding_status" do
    assert users(:completed).onboarded?
    assert_not users(:fresh).onboarded?
  end
end
