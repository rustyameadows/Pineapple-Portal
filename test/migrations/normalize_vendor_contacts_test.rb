require "test_helper"
require Rails.root.join("db/migrate/20260709150000_normalize_vendor_contacts")

class NormalizeVendorContactsTest < ActiveSupport::TestCase
  test "backfill builds a global directory and preserves each event vendor selection" do
    EventVendorContact.delete_all
    GlobalVendorContact.delete_all

    global_vendor = GlobalVendor.create!(
      name: "Backfill Test Vendor",
      contacts_jsonb: [
        { "name" => "Shared Contact", "email" => "shared@example.test" },
        { "name" => "Global Only", "phone" => "555-1000" }
      ]
    )
    local_event_vendor = EventVendor.create!(
      event: events(:one),
      global_vendor:,
      contacts_jsonb: [
        { "name" => "Shared Contact", "email" => "shared@example.test" },
        { "name" => "Local Only", "notes" => "Keep for this event" }
      ]
    )
    inherited_event_vendor = EventVendor.create!(
      event: events(:two),
      global_vendor:,
      contacts_jsonb: []
    )

    NormalizeVendorContacts::ContactBackfill.new.call

    assert_equal [ "Shared Contact", "Global Only", "Local Only" ], global_vendor.contacts.reload.map(&:name)
    assert_equal [ "Shared Contact", "Local Only" ], local_event_vendor.reload.selected_contacts.map(&:name)
    assert_equal [ "Shared Contact", "Global Only" ], inherited_event_vendor.reload.selected_contacts.map(&:name)
    assert_equal "Keep for this event", global_vendor.contacts.find_by!(name: "Local Only").notes
    assert_equal 3, global_vendor.contacts.count
  end
end
