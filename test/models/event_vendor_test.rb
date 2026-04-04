require "test_helper"

class EventVendorTest < ActiveSupport::TestCase
  setup do
    @event = events(:one)
  end

  test "requires a name" do
    vendor = @event.event_vendors.new(name: " ")

    assert_not vendor.valid?
    assert_includes vendor.errors[:name], "can't be blank"
  end

  test "enforces case insensitive uniqueness per event" do
    existing = event_vendors(:catering)

    vendor = @event.event_vendors.new(name: existing.name.upcase)

    assert_not vendor.valid?
    assert_includes vendor.errors[:name], "has already been taken"
  end

  test "assigns sequential position" do
    existing_position = @event.event_vendors.maximum(:position)

    vendor = @event.event_vendors.create!(name: "Florist Co")

    assert_equal existing_position + 1, vendor.position
  end

  test "sanitizes contact attributes and removes blanks" do
    vendor = @event.event_vendors.new(name: "AV Crew")
    vendor.contacts_attributes = {
      "0" => { name: "  Alice  ", email: "  alice@example.com  ", title: "", phone: "", notes: "  Arrives early  " },
      "1" => { name: " ", email: " ", phone: "" }
    }

    assert vendor.valid?

    expected = [{
      "name" => "Alice",
      "title" => nil,
      "email" => "alice@example.com",
      "phone" => nil,
      "notes" => "Arrives early"
    }]

    assert_equal expected, vendor.contacts
  end

  test "rejects malformed contacts payload" do
    vendor = @event.event_vendors.new(name: "Photo Booth")
    vendor.contacts_jsonb = "not-an-array"

    assert_not vendor.valid?
    assert_includes vendor.errors[:contacts_jsonb], "must be an array of contact hashes"
  end

  test "normalizes vendor type and social handle" do
    vendor = @event.event_vendors.create!(
      name: "DJ Collective",
      vendor_type: "  Entertainment  ",
      social_handle: "  @djcollective  "
    )

    assert_equal "Entertainment", vendor.vendor_type
    assert_equal "@djcollective", vendor.social_handle
  end

  test "vendor updates no longer enqueue the broad event refresh job" do
    vendor = event_vendors(:catering)
    enqueued_event_ids = []

    Documents::Generated::RefreshEventPacketCachesJob.stub :perform_later, ->(event_id) { enqueued_event_ids << event_id } do
      vendor.update!(social_handle: "@sunshineplus")
    end

    assert_equal [], enqueued_event_ids
  end
end
