# Gate for pages that need a logged-in user who has finished onboarding,
# such as listing a product (M2) or bidding (M4):
#
#   class BidsController < ApplicationController
#     before_action :require_onboarded
#
#     def create
#       grade = current_user.credit_grade   # "A".."D", for the bid limit
#       ...
#
# - Guests go to /login (and come back here after logging in).
# - Users who have not finished onboarding go to the step they reached, with
#   the message "Complete your profile to bid".
# - Views can use `onboarded?`.
module OnboardingGate
  extend ActiveSupport::Concern

  INCOMPLETE_MESSAGE = "Complete your profile to bid".freeze

  included do
    helper_method :onboarded?
  end

  private

  def onboarded?
    logged_in? && current_user.onboarded?
  end

  def require_onboarded
    return require_login unless logged_in?
    return if current_user.onboarded?

    redirect_to onboarding_step_path(current_user.onboarding_step_reached), alert: INCOMPLETE_MESSAGE
  end
end
