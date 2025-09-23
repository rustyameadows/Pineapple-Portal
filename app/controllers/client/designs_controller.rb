module Client
  class DesignsController < EventScopedController
    def index
      @documents = @event.documents.latest.client_visible.order(:title)
    end
  end
end
