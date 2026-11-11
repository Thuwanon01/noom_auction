module Admin
  class BaseController < ApplicationController
    before_action :require_login
    before_action :require_admin

    private

    def require_admin
      return if performed?

      head :forbidden unless current_user.admin?
    end
  end
end
