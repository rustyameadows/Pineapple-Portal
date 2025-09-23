module Events
  class PaymentsController < ApplicationController
    before_action :set_event
    before_action :set_payment, only: %i[show edit update destroy]

    def index
      @payments = @event.payments.ordered
    end

    def show; end

    def new
      @payment = @event.payments.new
    end

    def create
      @payment = @event.payments.new(payment_params)

      if @payment.save
        redirect_to event_payment_path(@event, @payment), notice: "Payment created."
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit; end

    def update
      if @payment.update(payment_params)
        redirect_to event_payment_path(@event, @payment), notice: "Payment updated."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      @payment.destroy
      redirect_to event_payments_path(@event), notice: "Payment removed."
    end

    private

    def set_event
      @event = Event.find(params[:event_id])
    end

    def set_payment
      @payment = @event.payments.find(params[:id])
    end

    def payment_params
      params.require(:payment).permit(:title, :amount, :due_on, :description, :client_visible, :status, :paid_at, :paid_by_client_at, :client_note)
    end
  end
end
