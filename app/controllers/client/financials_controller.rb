module Client
  class FinancialsController < PortalController
    def index
      @payments = @event.payments.client_visible.ordered
    end
  end
end
