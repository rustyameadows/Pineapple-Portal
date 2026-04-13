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
      assert_select "h2", text: "Key People"
      assert_select "input[name='event[key_people_label]'][value='VIPs & Family']", count: 1
      assert_select ".event-directory-card__meta", text: /full-width key people section title on the Wedding Party Reference packet/
      assert_select "h3", text: "VIP Family"
      assert_select "h3", text: "Jordan's Side"
      assert_select "input[name='event_guest[first_name]'][value='Jordan']", count: 1
      assert_select "input[name='event_guest[last_name]'][value='Rivers']", count: 1
      assert_select "select[name='event_guest[group_name]'] option", text: "VIP Family"
      assert_select "select[name='event_guest[group_name]'] option", text: "Jordan's Side"
      assert_select "select[name='event_guest[group_name]'] option[value='__new__']", text: "New group"
      assert_select "[data-controller='event-group-select']", minimum: 1
      assert_select "input[name='event_guest[custom_group_name]']", minimum: 1
      assert_select "input[type='checkbox'][name='event_guest[vip]']", minimum: 1
    end
  end
end
