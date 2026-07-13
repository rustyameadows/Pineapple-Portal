require "test_helper"

class EventVendorTest < ActiveSupport::TestCase
  setup do
    @event = events(:one)
  end

  test "planning company link cannot be removed directly but is removed with its event" do
    event = Event.create!(name: "Protected Planning Company Event")
    planning_vendor = event.event_vendors.find_by!(global_vendor: GlobalVendor.planning_company)

    assert_not planning_vendor.destroy
    assert_includes planning_vendor.errors[:base], "The planning company must remain associated with every event"

    assert_difference("EventVendor.count", -1) do
      event.destroy!
    end
  end

  test "requires a global vendor" do
    vendor = @event.event_vendors.new

    assert_not vendor.valid?
    assert_includes vendor.errors[:global_vendor], "must exist"
  end

  test "enforces one association to a global vendor per event" do
    global_vendor = GlobalVendor.create!(name: "One Per Event Vendor")
    @event.event_vendors.create!(global_vendor:)

    vendor = @event.event_vendors.new(global_vendor:)

    assert_not vendor.valid?
    assert_includes vendor.errors[:global_vendor_id], "has already been taken"
  end

  test "assigns sequential position" do
    existing_position = @event.event_vendors.maximum(:position)
    global_vendor = GlobalVendor.create!(name: "Florist Global")

    vendor = @event.event_vendors.create!(global_vendor:)

    assert_equal existing_position + 1, vendor.position
  end

  test "returns only selected contacts in selection order" do
    global_vendor = GlobalVendor.create!(
      name: "AV Global",
      contacts_attributes: {
        "0" => { name: "First Contact" },
        "1" => { name: "Second Contact" },
        "2" => { name: "Third Contact" }
      }
    )
    vendor = @event.event_vendors.create!(global_vendor:)
    vendor.replace_contact_ids!([ global_vendor.contacts.third.id, global_vendor.contacts.first.id ])

    assert_equal [ "Third Contact", "First Contact" ], vendor.selected_contacts.map(&:name)
    assert_equal [ global_vendor.contacts.third.id, global_vendor.contacts.first.id ], vendor.selected_contact_ids
  end

  test "replaces and clears contact selections without accepting another vendor's contacts" do
    global_vendor = GlobalVendor.create!(name: "Selection Global", contacts_attributes: { "0" => { name: "Selected" } })
    other_global_vendor = GlobalVendor.create!(name: "Other Selection Global", contacts_attributes: { "0" => { name: "Wrong" } })
    vendor = @event.event_vendors.create!(global_vendor:)
    selected_contact = global_vendor.contacts.first

    vendor.replace_contact_ids!([ selected_contact.id ])
    assert_equal [ selected_contact.id ], vendor.selected_contact_ids

    assert_raises(ActiveRecord::RecordNotFound) do
      vendor.replace_contact_ids!([ other_global_vendor.contacts.first.id ])
    end
    assert_equal [ selected_contact.id ], vendor.selected_contact_ids

    vendor.replace_contact_ids!([])
    assert_empty vendor.selected_contacts
  end

  test "cannot switch global vendors while old vendor contacts remain selected" do
    original = GlobalVendor.create!(name: "Original Selection", contacts_attributes: { "0" => { name: "Original Contact" } })
    replacement = GlobalVendor.create!(name: "Replacement Selection")
    vendor = @event.event_vendors.create!(global_vendor: original)
    vendor.replace_contact_ids!([ original.contacts.first.id ])

    vendor.global_vendor = replacement

    assert_not vendor.valid?
    assert_includes vendor.errors[:selected_contacts], "must belong to the selected global vendor"
  end

  test "normalizes vendor type and social handle" do
    global_vendor = GlobalVendor.create!(name: "DJ Collective")
    vendor = @event.event_vendors.create!(
      global_vendor:,
      vendor_type: "  Entertainment  ",
      social_handle: "  @djcollective  "
    )

    assert_equal "Entertainment", vendor.vendor_type
    assert_equal "@djcollective", vendor.social_handle
  end

  test "normalizes team meals while preserving markdown and newlines" do
    global_vendor = GlobalVendor.create!(name: "Meal Partner")
    vendor = @event.event_vendors.create!(
      global_vendor:,
      team_meals: "  **Vendor meals**\n\nPickup from [kitchen](https://example.com/kitchen).  "
    )

    assert_equal "**Vendor meals**\n\nPickup from [kitchen](https://example.com/kitchen).", vendor.team_meals

    vendor.update!(team_meals: " \n ")

    assert_nil vendor.team_meals
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
