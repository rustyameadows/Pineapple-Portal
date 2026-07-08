module Client
  class BaseController < ApplicationController
    include ClientPortalAuthentication

    layout "client"

    skip_before_action :require_login
    before_action :require_portal_access

    helper_method :nav_link_class,
                  :portal_current_user,
                  :financial_portal_access?

    private

    def portal_current_user
      current_client_user || current_user
    end

    def require_portal_access
      return if current_client_user.present?
      return if current_user&.planner_or_admin?

      redirect_to client_login_path(return_to: request.get? ? request.fullpath : nil),
                  alert: "Please sign in to the client portal."
    end

    def authorize_portal_event_access!(event)
      if current_user&.planner_or_admin?
        raise ActiveRecord::RecordNotFound unless current_user_can_access_event?(event)

        return
      end

      if current_client_user.present? && event
        return if client_can_access_event?(current_client_user, event)
      end

      redirect_to client_login_path(return_to: request.get? ? request.fullpath : nil),
                  alert: "Access to this event is unavailable."
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
