require "test_helper"

module Events
  class PeopleControllerTest < ActionDispatch::IntegrationTest
    setup do
      @event = events(:one)
      log_in_as(users(:one))
    end

    test "shows people directory" do
      vendor = event_vendors(:catering)
      vendor.update_columns(name: "Legacy Sunshine Name", social_handle: "@legacy-sunshine")
      vendor.global_vendor.contacts.create!(name: "Unselected Sunshine Contact", email: "unselected@sunshine.test")

      get event_people_url(@event)
      assert_response :success
      assert_select "h1", text: "People"
      assert_select "h2", text: "Key People"
      assert_select "input[name='event[key_people_label]'][value='VIPs & Family']", count: 1
      assert_select ".event-directory-card__meta", text: /full-width key people section title on the Wedding Party Reference packet/
      assert_select "input[name='event_key_person_group[name]'][value='VIP Family']", count: 1
      assert_select "input[name='event_key_person_group[name]'][value=\"Jordan's Side\"]", count: 1
      assert_select "input[name='event_guest[first_name]'][value='Jordan']", count: 1
      assert_select "input[name='event_guest[last_name]'][value='Rivers']", count: 1
      assert_select "select[name='event_guest[event_key_person_group_id]'] option", text: "VIP Family"
      assert_select "select[name='event_guest[event_key_person_group_id]'] option", text: "Jordan's Side"
      assert_select "select[name='event_guest[event_key_person_group_id]'] option[value='__new__']", text: "New group"
      assert_select "[data-controller='event-group-select']", minimum: 1
      assert_select "input[name='event_guest[custom_group_name]']", minimum: 1
      assert_select "input[type='checkbox'][name='event_guest[vip]']", minimum: 1
      assert_select ".event-directory-card__meta", text: /Timeline tag:\s*Wedding Party Side A/
      assert_select ".event-directory-card__meta", text: /Timeline tag:\s*Wedding Party Side B/
      assert_select ".event-directory-card h3", text: "Sunshine Catering", count: 1
      assert_select ".event-directory-card__meta", text: "Catering", count: 1
      assert_select ".event-directory-list strong", text: "Maria Cater", count: 1
      assert_select ".event-directory-list__meta", text: /maria@sunshine\.test/
      assert_no_match(/Legacy Sunshine Name|Unselected Sunshine Contact/, response.body)
    end
  end
end
