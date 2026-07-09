require "test_helper"

class WelcomeControllerTest < ActionDispatch::IntegrationTest
  test "redirects guests to login" do
    get root_url
    assert_redirected_to login_url
  end

  test "loads all active events for admin" do
    post login_url, params: { email: users(:two).email, password: "password123" }

    get root_url
    assert_response :success
    assert_select "h1", text: "Your Active Events"
    assert_select "a.event-section__cta[href='#{events_path}']", text: "All Events"
    assert_select "a.event-section__cta[href='#{new_event_path}']", text: "New Event"
    assert_match events(:one).name, response.body
    assert_match events(:two).name, response.body
  end

  test "loads only assigned active events for planner and hides admin actions" do
    post login_url, params: { email: users(:one).email, password: "password123" }

    get root_url
    assert_response :success
    assert_select "h1", text: "Your Active Events"
    assert_select "a.event-section__cta[href='#{events_path}']", text: "All Events", count: 0
    assert_select "a.event-section__cta[href='#{new_event_path}']", text: "New Event", count: 0
    assert_match events(:one).name, response.body
    assert_no_match events(:two).name, response.body
  end
end
