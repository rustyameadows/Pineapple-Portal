module Client
  class PacketsController < PortalController
    def index
      @packets = @event.documents
                       .packets_portal_listing
                       .order(updated_at: :desc, title: :asc)
    end
  end
end
