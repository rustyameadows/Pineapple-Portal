module Client
  class FinancialsController < EventScopedController
    def index
      @payments = @event.payments.client_visible.ordered
    end
  end
end
