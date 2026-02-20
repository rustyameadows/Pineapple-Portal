require "test_helper"

module Events
  class CalendarItemsControllerTest < ActionDispatch::IntegrationTest
    setup do
      log_in_as(users(:one))
      @event = events(:one)
      @calendar = event_calendars(:run_of_show)
    end

    test "new preselects default tag when name matches case-insensitively" do
      tag = @calendar.event_calendar_tags.create!(name: "Decisions")

      get new_event_calendar_item_url(@event), params: { default_tag_name: "decisions" }

      assert_response :success
      assert_select "input#calendar_item_tag_#{tag.id}[type='checkbox'][name='calendar_item[event_calendar_tag_ids][]'][checked]", count: 1
    end

    test "new does not create or preselect tag when default tag name is missing" do
      existing_tag_count = @calendar.event_calendar_tags.count

      get new_event_calendar_item_url(@event), params: { default_tag_name: "Missing Decisions Tag" }

      assert_response :success
      assert_equal existing_tag_count, @calendar.event_calendar_tags.count
      assert_select "input[type='checkbox'][name='calendar_item[event_calendar_tag_ids][]'][checked]", count: 0
    end
  end
end
