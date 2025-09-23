require "test_helper"

module Client
  class PaymentsControllerTest < ActionDispatch::IntegrationTest
    setup do
      @event = events(:one)
      @payment = payments(:visible_payment)
      log_in_as(users(:one))
    end

    test "shows payment detail" do
      get client_event_payment_url(@event, @payment)
      assert_response :success
      assert_select "h1", text: @payment.title
      assert_select "form", action: mark_paid_client_event_payment_path(@event, @payment)
    end

    test "marks payment as paid" do
      patch mark_paid_client_event_payment_url(@event, @payment), params: { payment: { client_note: "Check #42" } }

      assert_redirected_to client_event_payment_url(@event, @payment)
      @payment.reload
      assert @payment.paid?
      assert_equal "Check #42", @payment.client_note
    end

    test "already paid payment redirects with notice" do
      payment = payments(:paid_payment)
      patch mark_paid_client_event_payment_url(@event, payment)

      assert_redirected_to client_event_payment_url(@event, payment)
    end
  end
end
