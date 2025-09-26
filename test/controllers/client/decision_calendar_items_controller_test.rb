require "test_helper"

module Client
  class DecisionCalendarItemsControllerTest < ActionDispatch::IntegrationTest
    setup do
      @event = events(:one)
      @item = calendar_items(:decision_flowers)
      log_in_client_portal(users(:client_contact))
    end

    test "shows decision item as json" do
      get client_event_decision_calendar_item_url(@event, @item, format: :json)

      assert_response :success
      payload = JSON.parse(response.body)
      assert_equal @item.title, payload.dig("calendar_item", "title")
    end

    test "updates decision item" do
      patch client_event_decision_calendar_item_url(@event, @item), params: {
        calendar_item: {
          status: "completed",
          vendor_name: "Flora Co.",
          notes: "Signed contract"
        }
      }

      assert_redirected_to client_event_calendar_url(@event, "decision-calendar")
      @item.reload
      assert_equal "completed", @item.status
      assert_equal "Flora Co.", @item.vendor_name
      assert_equal "Signed contract", @item.notes
    end
  end
end
