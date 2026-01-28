require "test_helper"

module Client
  class FinancialsControllerTest < ActionDispatch::IntegrationTest
    setup do
      @event = events(:one)
      @client = users(:client_contact)
      @client.update!(can_view_financials: true)
      log_in_client_portal(@client)
    end

    test "shows financial resources and payments" do
      get client_event_financials_url(@event)

      assert_response :success
      assert_select "h1", text: "Financial Management"
      assert_select "td", text: "Payment Portal"
      assert_select "td", text: "Production Contract"
      assert_select "h2", text: "Payments"
      assert_select "td", text: payments(:visible_payment).title
    end

    test "hides payments when disabled" do
      @event.update!(financial_payments_enabled: false)

      get client_event_financials_url(@event)

      assert_response :success
      assert_select "h2", text: "Payments", count: 0
      assert_select "td", text: payments(:visible_payment).title, count: 0
    end

    test "redirects without financial access" do
      @client.update!(can_view_financials: false)

      get client_event_financials_url(@event)

      assert_redirected_to client_event_url(@event.portal_slug)
    end
  end
end
