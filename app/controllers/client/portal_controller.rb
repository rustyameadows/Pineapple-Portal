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
                           Event.find_by(portal_slug: slug) || Event.find_by(id: slug) || raise(ActiveRecord::RecordNotFound)
                         else
                           Event.find(params[:event_id])
                         end
    end

    def authorize_event_access!
      authorize_portal_event_access!(current_event)
    end
  end
end
