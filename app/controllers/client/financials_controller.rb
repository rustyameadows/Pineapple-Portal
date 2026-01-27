module Client
  class FinancialsController < PortalController
    before_action :require_financial_access

    def index
      @financial_links = @event.event_links.financial.ordered
      @financial_documents = @event.documents.latest.financial_portal_visible.where.not(storage_uri: nil).order(updated_at: :desc, title: :asc)
      @payments = []

      return unless @event.financial_payments_enabled?

      @payments = @event.payments.client_visible.ordered
    end

    private

    def require_financial_access
      return if financial_portal_access?

      redirect_to client_event_path(@event), alert: "Financial access is required to view this page."
    end
  end
end
