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
      @current_event ||= Event.find(params[:event_id])
    end

    def authorize_event_access!
      return if current_user&.planner_or_admin?

      if current_client_user.present?
        membership = @event.client_team_members.find_by(user_id: current_client_user.id, client_visible: true)
        return if membership.present?
      end

      reset_client_session
      redirect_to client_login_path, alert: "Access to this event is unavailable."
    end
  end
end
