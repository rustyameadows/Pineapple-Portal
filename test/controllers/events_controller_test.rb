require "test_helper"

class EventsControllerTest < ActionDispatch::IntegrationTest
  setup do
    log_in_as(users(:one))
  end

  test "lists events" do
    get events_url
    assert_response :success
    assert_select "h1", text: "Active Projects"
  end

  test "creates event" do
    assert_difference("Event.count") do
      post events_url, params: { event: { name: "Rehearsal", starts_on: "2025-12-01" } }
    end

    assert_redirected_to event_url(Event.last)
  end
end
