module Client
  class PaymentsController < EventScopedController
    def mark_paid
      @payment = @event.payments.client_visible.find(params[:id])
      note = payment_params[:client_note]

      if @payment.paid?
        @payment.update(client_note: note.presence) if note.present?
        redirect_back fallback_location: client_event_financials_path(@event), notice: "Payment already marked as paid."
      else
        begin
          @payment.mark_paid!(by_client: true, note: note)
          redirect_back fallback_location: client_event_financials_path(@event), notice: "Thanks! We'll let your planner know this payment is on the way."
        rescue ActiveRecord::RecordInvalid => e
          redirect_back fallback_location: client_event_financials_path(@event), alert: e.record.errors.full_messages.to_sentence
        end
      end
    end

    private

    def payment_params
      params.fetch(:payment, {}).permit(:client_note)
    end
  end
end
