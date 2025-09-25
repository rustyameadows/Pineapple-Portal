module Client
  class PortalController < BaseController
    before_action :set_event

    helper_method :current_event

    private

    def set_event
      @event = current_event
    end

    def current_event
      @current_event ||= Event.find(params[:event_id])
    end
  end
end
