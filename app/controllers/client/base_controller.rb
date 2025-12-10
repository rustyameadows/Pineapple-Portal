module Client
  class BaseController < ApplicationController
    layout "client"

    skip_before_action :require_login
    before_action :require_portal_access

    helper_method :nav_link_class,
                  :current_client_user,
                  :client_logged_in?,
                  :portal_current_user,
                  :financial_portal_access?

    private

    def current_client_user
      @current_client_user ||= User.find_by(id: session[:client_user_id]) if session[:client_user_id]
    end

    def client_logged_in?
      current_client_user.present?
    end

    def portal_current_user
      current_client_user || current_user
    end

    def require_portal_access
      return if current_client_user.present?
      return if current_user&.planner_or_admin?

      redirect_to client_login_path, alert: "Please sign in to the client portal."
    end

    def reset_client_session
      session.delete(:client_user_id)
      @current_client_user = nil
    end

    def financial_portal_access?
      user = portal_current_user
      return true unless user&.client?

      user.can_view_financials?
    end

    def nav_link_class(target_path, starts_with: nil)
      classes = ["client-shell__nav-link"]
      is_active = helpers.current_page?(target_path)
      is_active ||= request.path.start_with?(starts_with) if starts_with.present?
      classes << "client-shell__nav-link--active" if is_active
      classes.join(" ")
    end
  end
end
