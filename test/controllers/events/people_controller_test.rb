require "test_helper"

module Events
  class PeopleControllerTest < ActionDispatch::IntegrationTest
    setup do
      @event = events(:one)
      log_in_as(users(:one))
    end

    test "shows people directory" do
      get event_people_url(@event)
      assert_response :success
      assert_select "h1", text: "People"
    end
  end
end
