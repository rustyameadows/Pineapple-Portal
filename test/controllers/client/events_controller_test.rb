require "test_helper"

module Client
  class EventsControllerTest < ActionDispatch::IntegrationTest
    setup do
      @event = events(:one)
      log_in_as(users(:one))
    end

    test "shows planning team section" do
      get client_event_url(@event)
      assert_response :success
      assert_select "section.client-team h2", text: "My Planning Team"
      assert_select "section.client-team li", text: /Ada Fixture/
    end
  end
end
