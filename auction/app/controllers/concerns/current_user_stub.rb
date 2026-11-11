# TEMPORARY. Real login/logout is M1.2 (#8) and the onboarding gate is M1.10 (#16).
# This only exposes the same helper names (current_user, require_login, require_onboarded) so M2 can be
# built and tested. When #8/#16 land, delete this file and the dev_login route and keep their helpers.
module CurrentUserStub
  extend ActiveSupport::Concern

  included do
    helper_method :current_user, :logged_in?
  end

  private

  def current_user
    return @current_user if defined?(@current_user)

    @current_user = User.find_by(id: session[:user_id])
  end

  def logged_in? = current_user.present?

  def require_login
    redirect_to login_path, alert: "กรุณาเข้าสู่ระบบก่อน" unless logged_in?
  end

  def require_onboarded
    return if performed? # require_login already redirected

    redirect_to root_path, alert: "Complete your profile to continue" unless current_user.completed?
  end
end
