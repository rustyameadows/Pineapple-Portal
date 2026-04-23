require "test_helper"

module Events
  class EventGuestsControllerTest < ActionDispatch::IntegrationTest
    setup do
      @event = events(:one)
      @guest = event_guests(:vip_family_primary)
      @vip_family_group = event_key_person_groups(:vip_family)
      @jordan_side_group = event_key_person_groups(:jordan_side)
      log_in_as(users(:one))
    end

    test "creates a key person with vip flag" do
      assert_difference("EventGuest.count", 1) do
        post event_event_guests_url(@event), params: {
          event_guest: {
            first_name: "Avery",
            last_name: "Brooks",
            relationship: "Officiant",
            event_key_person_group_id: @vip_family_group.id,
            vip: "1"
          },
          return_to: event_people_path(@event)
        }
      end

      created_guest = EventGuest.order(:id).last

      assert_redirected_to event_people_url(@event)
      assert_equal EventGuest::KINDS[:key_person], created_guest.kind
      assert_equal "Avery", created_guest.first_name
      assert_equal "Brooks", created_guest.last_name
      assert_equal "Officiant", created_guest.relationship
      assert_equal "VIP Family", created_guest.group_name
      assert_equal @vip_family_group.id, created_guest.event_key_person_group_id
      assert created_guest.vip?
    end

    test "creates a key person with a new custom group" do
      assert_difference("EventGuest.count", 1) do
        assert_difference("EventKeyPersonGroup.count", 1) do
          assert_difference("EventCalendarTag.count", 1) do
            post event_event_guests_url(@event), params: {
              event_guest: {
                first_name: "Skye",
                last_name: "Bennett",
                relationship: "Reader",
                event_key_person_group_id: "__new__",
                custom_group_name: "Ceremony Readers",
                vip: "0"
              },
              return_to: event_people_path(@event)
            }
          end
        end
      end

      created_guest = EventGuest.order(:id).last

      assert_equal "Ceremony Readers", created_guest.group_name
      assert_equal "Wedding Party Side C", created_guest.event_key_person_group.event_calendar_tag.name
    end

    test "updates a key person" do
      patch event_event_guest_url(@event, @guest), params: {
        event_guest: {
          first_name: "Jordan",
          last_name: "Rivers",
          relationship: "Lead Host",
          event_key_person_group_id: @vip_family_group.id,
          vip: "0"
        },
        return_to: event_people_path(@event)
      }

      assert_redirected_to event_people_url(@event)

      @guest.reload
      assert_equal "Lead Host", @guest.relationship
      assert_not @guest.vip?
    end

    test "moves a key person to a different side" do
      patch event_event_guest_url(@event, @guest), params: {
        event_guest: {
          first_name: "Jordan",
          last_name: "Rivers",
          relationship: "Host",
          event_key_person_group_id: @jordan_side_group.id,
          vip: "1"
        },
        return_to: event_people_path(@event)
      }

      assert_redirected_to event_people_url(@event)

      @guest.reload
      assert_equal @jordan_side_group.id, @guest.event_key_person_group_id
      assert_equal "Jordan's Side", @guest.group_name
    end

    test "destroys a key person" do
      assert_difference("EventGuest.count", -1) do
        delete event_event_guest_url(@event, @guest), params: { return_to: event_people_path(@event) }
      end

      assert_redirected_to event_people_url(@event)
    end

    test "moves a key person within the ordered key people list" do
      moving_guest = event_guests(:jordan_side_primary)
      previous_guest = event_guests(:vip_family_secondary)

      patch move_up_event_event_guest_url(@event, moving_guest), params: { return_to: event_people_path(@event) }

      assert_redirected_to event_people_url(@event)
      assert_equal 2, moving_guest.reload.position
      assert_equal 3, previous_guest.reload.position
    end
  end
end
