require "test_helper"

module Events
  class PaymentsControllerTest < ActionDispatch::IntegrationTest
    setup do
      @event = events(:one)
      @payment = payments(:visible_payment)
      log_in_as(users(:two))
    end

    test "show renders refreshed payment layout" do
      get event_payment_url(@event, @payment)

      assert_response :success
      assert_select ".event-payments__top-actions"
      assert_select ".event-payments__hero"
      assert_select ".event-payments__card", minimum: 4
      assert_select ".event-payments__attachments-list"
      assert_select ".event-payments__attachments-form"
    end

    test "show renders fallback copy for missing notes" do
      payment = @event.payments.create!(
        title: "No Notes Payment",
        amount: 200,
        status: :pending,
        client_visible: false,
        description: nil,
        client_note: nil
      )

      get event_payment_url(@event, payment)

      assert_response :success
      assert_select "h2", text: "Planner Notes"
      assert_select "h2", text: "Client Note"
      assert_select ".event-payments__card-body", text: /No notes/
      assert_select ".event-payments__card-body", text: /No client note/
    end

    test "show renders status and visibility pills" do
      get event_payment_url(@event, @payment)

      assert_response :success
      assert_select ".event-payments__status-pill--pending", text: /Pending/
      assert_select ".event-payments__visibility-pill--visible", text: /Visible/
    end

    test "show renders paid status and timing metadata" do
      paid_payment = payments(:paid_payment)
      paid_payment.update!(paid_by_client_at: Time.current)

      get event_payment_url(@event, paid_payment)

      assert_response :success
      assert_select ".event-payments__status-pill--paid", text: /Paid/
      assert_select "h2", text: "Payment Timing"
      assert_select ".event-payments__meta-grid dd", minimum: 2
    end

    test "show renders payment attachments" do
      @payment.attachments.create!(document: documents(:contract_v1), context: :other, position: 1)

      get event_payment_url(@event, @payment)

      assert_response :success
      assert_select "h2", text: "Attachments"
      assert_select "a", text: "Production Contract"
    end

    test "new renders sectioned form" do
      get new_event_payment_url(@event)

      assert_response :success
      assert_select ".event-payments-form__section-title", text: "Payment Details"
      assert_select ".event-payments-form__section-title", text: "Portal & Status"
      assert_select ".event-payments-form__section-title", text: "Client Record"
      assert_select "input[name='payment[title]']"
      assert_select "select[name='payment[status]']"
    end

    test "edit renders sectioned form" do
      get edit_event_payment_url(@event, @payment)

      assert_response :success
      assert_select ".event-payments-form__section-title", text: "Payment Details"
      assert_select ".event-payments-form__section-title", text: "Portal & Status"
      assert_select ".event-payments-form__section-title", text: "Client Record"
      assert_select "textarea[name='payment[client_note]']"
    end

    test "create update and destroy keep controller behavior" do
      assert_difference("Payment.count", 1) do
        post event_payments_url(@event), params: {
          payment: {
            title: "Retainer",
            amount: 750.0,
            due_on: Date.current,
            description: "Retainer payment",
            client_visible: true,
            status: :pending
          }
        }
      end

      created = Payment.order(:created_at).last
      assert_redirected_to event_payment_url(@event, created)

      patch event_payment_url(@event, created), params: {
        payment: {
          status: :paid,
          client_note: "Paid via ACH"
        }
      }
      assert_redirected_to event_payment_url(@event, created)

      assert_difference("Payment.count", -1) do
        delete event_payment_url(@event, created)
      end
      assert_redirected_to event_payments_url(@event)
    end
  end
end
