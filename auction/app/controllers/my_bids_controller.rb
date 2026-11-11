class MyBidsController < ApplicationController
  def index
    return redirect_to(login_path, alert: "Log in to see your bids") unless current_user

    @rows = MyBids.for(current_user)
  end
end
