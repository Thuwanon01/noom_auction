# Session-based login for the whole app.
#
#   before_action :require_login   # guests are sent to /login, then back here
#
# Views can call `current_user` and `logged_in?`.
module Authentication
  extend ActiveSupport::Concern

  included do
    helper_method :current_user, :logged_in?
  end

  private

  def current_user
    return @current_user if defined?(@current_user)

    @current_user = session[:user_id] && User.find_by(id: session[:user_id])
  end

  def logged_in?
    current_user.present?
  end

  def require_login
    return if logged_in?

    session[:return_to] = request.fullpath if request.get?
    redirect_to login_path, alert: "Please log in to continue"
  end

  def log_in(user)
    return_to = session[:return_to]
    reset_session # prevent session fixation
    session[:user_id] = user.id
    session[:return_to] = return_to if return_to
    @current_user = user
  end

  def log_out
    reset_session
    @current_user = nil
  end

  def pop_return_to
    session.delete(:return_to)
  end
end
