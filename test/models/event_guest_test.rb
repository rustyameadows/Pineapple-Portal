require "test_helper"

class EventGuestTest < ActiveSupport::TestCase
  test "requires core attributes" do
    guest = EventGuest.new

    assert_not guest.valid?
    assert_includes guest.errors[:event], "must exist"
    assert_equal EventGuest::KINDS[:key_person], guest.kind
    assert_includes guest.errors[:first_name], "can't be blank"
    assert_includes guest.errors[:last_name], "can't be blank"
    assert_includes guest.errors[:relationship], "can't be blank"
    assert_includes guest.errors[:group_name], "can't be blank"
  end

  test "normalizes fields and exposes full name" do
    event = Event.create!(name: "Normalization Event")
    guest = event.event_guests.create!(
      kind: EventGuest::KINDS[:key_person],
      first_name: "  Avery ",
      last_name: " Brooks  ",
      relationship: " Officiant ",
      group_name: " VIP Circle ",
      vip: true
    )

    assert_equal "Avery", guest.first_name
    assert_equal "Brooks", guest.last_name
    assert_equal "Officiant", guest.relationship
    assert_equal "VIP Circle", guest.group_name
    assert_equal "VIP Circle", guest.event_key_person_group.name
    assert_equal "Wedding Party Side A", guest.event_key_person_group.event_calendar_tag.name
    assert_equal "Avery Brooks", guest.full_name
  end

  test "key_people scope returns only key person records" do
    event = events(:two)
    key_person = event.event_guests.create!(
      kind: EventGuest::KINDS[:key_person],
      first_name: "Casey",
      last_name: "Morgan",
      relationship: "Sibling",
      group_name: "Family",
      vip: false
    )

    assert_equal [key_person.id], event.event_guests.key_people.pluck(:id)
  end

  test "key people require a stable side or group" do
    event = Event.create!(name: "Missing Group Event")
    guest = event.event_guests.new(
      kind: EventGuest::KINDS[:key_person],
      first_name: "Sam",
      last_name: "Taylor",
      relationship: "Reader",
      vip: false
    )

    assert_not guest.valid?
    assert_includes guest.errors[:group_name], "can't be blank"
    assert_includes guest.errors[:event_key_person_group], "can't be blank"
  end

  test "assigns positions sequentially on create" do
    event = Event.create!(name: "Ordering Event")
    first_guest = event.event_guests.create!(
      kind: EventGuest::KINDS[:key_person],
      first_name: "Jamie",
      last_name: "Lane",
      relationship: "Friend",
      group_name: "Side A",
      vip: false
    )
    second_guest = event.event_guests.create!(
      kind: EventGuest::KINDS[:key_person],
      first_name: "Rowan",
      last_name: "Blake",
      relationship: "Cousin",
      group_name: "Side B",
      vip: false
    )

    assert_equal 1, first_guest.position
    assert_equal 2, second_guest.position
  end
end
