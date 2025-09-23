module Client
  class PaymentsController < EventScopedController
    before_action :set_payment, only: %i[show mark_paid]

    def show
      @attachments = @payment.attachments.includes(document: :event)
    end

    def mark_paid
      note = payment_params[:client_note]

      if @payment.paid?
        @payment.update(client_note: note.presence) if note.present?
        redirect_to client_event_payment_path(@event, @payment), notice: "Payment already marked as paid."
      else
        begin
          @payment.mark_paid!(by_client: true, note: note)
          redirect_to client_event_payment_path(@event, @payment), notice: "Thanks! We'll let your planner know this payment is on the way."
        rescue ActiveRecord::RecordInvalid => e
          redirect_to client_event_payment_path(@event, @payment), alert: e.record.errors.full_messages.to_sentence
        end
      end
    end

    private

    def set_payment
      @payment = @event.payments.client_visible.find(params[:id])
    end

    def payment_params
      params.fetch(:payment, {}).permit(:client_note)
    end
  end
end
