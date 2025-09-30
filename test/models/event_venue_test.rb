require "test_helper"

class EventVenueTest < ActiveSupport::TestCase
  setup do
    @event = events(:one)
  end

  test "requires a name" do
    venue = @event.event_venues.new(name: "")

    assert_not venue.valid?
    assert_includes venue.errors[:name], "can't be blank"
  end

  test "enforces case insensitive name uniqueness" do
    existing = event_venues(:main_hall)
    venue = @event.event_venues.new(name: existing.name.swapcase)

    assert_not venue.valid?
    assert_includes venue.errors[:name], "has already been taken"
  end

  test "assigns sequential position on create" do
    existing_position = @event.event_venues.maximum(:position)

    venue = @event.event_venues.create!(name: "Skyline Loft")

    assert_equal existing_position + 1, venue.position
  end

  test "strips name before validation" do
    venue = @event.event_venues.create!(name: "  Riverside Plaza  ")

    assert_equal "Riverside Plaza", venue.name
  end

  test "filters blank contacts" do
    venue = @event.event_venues.new(name: "Green Gardens")
    venue.contacts_attributes = [
      { name: "  Greta  ", phone: "111-222-3333" },
      { name: "", email: "" }
    ]

    assert venue.valid?

    assert_equal [
      {
        "name" => "Greta",
        "title" => nil,
        "email" => nil,
        "phone" => "111-222-3333",
        "notes" => nil
      }
    ], venue.contacts
  end
end
