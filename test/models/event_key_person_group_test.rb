require "test_helper"

class EventKeyPersonGroupTest < ActiveSupport::TestCase
  test "backfill creates stable groups, tags, and guest links from legacy group names" do
    event = Event.create!(name: "Legacy Wedding")
    now = Time.current

    EventGuest.insert_all!([
      {
        event_id: event.id,
        kind: EventGuest::KINDS[:key_person],
        first_name: "Alex",
        last_name: "Stone",
        relationship: "Sibling",
        group_name: "Bride",
        vip: false,
        position: 1,
        created_at: now,
        updated_at: now
      },
      {
        event_id: event.id,
        kind: EventGuest::KINDS[:key_person],
        first_name: "Jamie",
        last_name: "Cross",
        relationship: "Friend",
        group_name: "Groom",
        vip: false,
        position: 2,
        created_at: now,
        updated_at: now
      }
    ])

    assert_difference("EventKeyPersonGroup.count", 2) do
      assert_difference("EventCalendarTag.count", 2) do
        EventKeyPersonGroup.backfill_for_event!(event)
      end
    end

    groups = event.reload.event_key_person_groups.ordered.to_a

    assert_equal ["Bride", "Groom"], groups.map(&:name)
    assert_equal ["Wedding Party Side A", "Wedding Party Side B"], groups.map { |group| group.event_calendar_tag.name }
    assert_equal groups.map(&:id), event.event_guests.key_people.ordered.pluck(:event_key_person_group_id)
  end

  test "renaming a group keeps its tag connection and syncs guest group names" do
    group = event_key_person_groups(:vip_family)
    guest = event_guests(:vip_family_primary)
    original_tag_name = group.event_calendar_tag.name

    group.update!(name: "Bride's Side")

    assert_equal original_tag_name, group.reload.event_calendar_tag.name
    assert_equal "Bride's Side", guest.reload.group_name
  end
end
