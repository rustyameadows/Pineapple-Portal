module Client
  class PortalController < BaseController
    before_action :set_event
    before_action :authorize_event_access!

    helper_method :current_event

    private

    def set_event
      @event = current_event
    end

    def current_event
      slug = params[:event_slug].presence || params[:slug]
      @current_event ||= if slug.present?
                           Event.find_by!(portal_slug: slug)
                         else
                           Event.find(params[:event_id])
                         end
    end

    def authorize_event_access!
      return if current_user&.planner_or_admin?

      event = current_event

      if current_client_user.present? && event
        membership = event.client_team_members.find_by(user_id: current_client_user.id, client_visible: true)
        return if membership.present?
      end

      reset_client_session
      redirect_to client_login_path, alert: "Access to this event is unavailable."
    end
  end
end
