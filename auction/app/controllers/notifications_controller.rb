# In-app notifications (M4.12). Opening the list marks everything read;
# the page still highlights what was unread when it was opened.
class NotificationsController < ApplicationController
  def index
    return redirect_to(login_path, alert: "Log in to see your notifications") unless current_user

    @notifications = current_user.notifications.newest_first.includes(auction: :product).limit(100).to_a
    @unread_ids = @notifications.reject(&:read_at).map(&:id)
    current_user.notifications.unread.update_all(read_at: Time.current) if @unread_ids.any?
  end
end
