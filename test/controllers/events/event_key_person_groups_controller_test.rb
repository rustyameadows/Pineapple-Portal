require "test_helper"

module Events
  class EventKeyPersonGroupsControllerTest < ActionDispatch::IntegrationTest
    setup do
      @event = events(:one)
      @group = event_key_person_groups(:vip_family)
      log_in_as(users(:one))
    end

    test "renames a group without renaming its backing tag" do
      original_tag_name = @group.event_calendar_tag.name

      patch event_event_key_person_group_url(@event, @group), params: {
        event_key_person_group: {
          name: "Bride's Side"
        },
        return_to: event_people_path(@event)
      }

      assert_redirected_to event_people_url(@event)
      assert_equal "Bride's Side", @group.reload.name
      assert_equal original_tag_name, @group.event_calendar_tag.name
      assert_equal "Bride's Side", event_guests(:vip_family_primary).reload.group_name
    end
  end
end
