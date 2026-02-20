require "test_helper"

class EventsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @event = events(:one)
    log_in_as(users(:one))
  end

  test "lists events" do
    get events_url
    assert_response :success
    assert_select "h1", text: "Active Projects"
  end

  test "renders styled new event page" do
    get new_event_url

    assert_response :success
    assert_select ".event-layout.event-layout--index"
    assert_select "h1.event-section__title", text: "Create Event"
    assert_select "a.event-section__link[href='#{events_path}']", text: "Back to events"
    assert_select "form.event-create-form", count: 1
    assert_select "input[name='event[name]']"
    assert_select "input[name='event[starts_on]']"
    assert_select "input[name='event[ends_on]']"
    assert_select "input[name='event[location]']"
    assert_select "input[name='event[location_secondary]']"
  end

  test "renders styled edit event page" do
    get edit_event_url(@event)

    assert_response :success
    assert_select ".event-layout.event-layout--index"
    assert_select "h1.event-section__title", text: "Edit Event"
    assert_select "a.event-section__link[href='#{event_path(@event)}']", text: "Back to event"
    assert_select "form.event-create-form", count: 1
  end

  test "creates event" do
    assert_difference("Event.count") do
      post events_url, params: { event: { name: "Rehearsal", starts_on: "2025-12-01" } }
    end

    assert_redirected_to event_url(Event.last)
  end

  test "invalid create rerenders styled form with errors" do
    assert_no_difference("Event.count") do
      post events_url, params: { event: { name: "", starts_on: "2025-12-01" } }
    end

    assert_response :unprocessable_content
    assert_select ".event-create-form__errors", count: 1
    assert_select ".event-create-form__errors li", text: "Name can't be blank"
  end
end
