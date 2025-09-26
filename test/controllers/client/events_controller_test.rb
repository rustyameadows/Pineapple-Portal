require "test_helper"

module Client
  class EventsControllerTest < ActionDispatch::IntegrationTest
    setup do
      @event = events(:one)
      log_in_client_portal(users(:client_contact))
    end

    test "shows planning team section" do
      get client_event_url(@event)
      assert_response :success
      assert_select "section.client-planning-team h2.client-planning-team__heading", text: "My Planning Team"
      assert_select "section.client-planning-team li.client-planning-team__item", text: /Ada Fixture/
    end
  end
end
