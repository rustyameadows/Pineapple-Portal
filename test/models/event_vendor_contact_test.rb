require "test_helper"

class EventVendorContactTest < ActiveSupport::TestCase
  setup do
    @global_vendor = GlobalVendor.create!(
      name: "Selection Join Vendor",
      contacts_attributes: {
        "0" => { name: "First" },
        "1" => { name: "Second" }
      }
    )
    @event_vendor = events(:one).event_vendors.create!(global_vendor: @global_vendor)
  end

  test "requires the contact to belong to the event vendor's global vendor" do
    other_vendor = GlobalVendor.create!(name: "Wrong Join Vendor", contacts_attributes: { "0" => { name: "Wrong" } })
    selection = @event_vendor.event_vendor_contacts.new(global_vendor_contact: other_vendor.contacts.first)

    assert_not selection.valid?
    assert_includes selection.errors[:global_vendor_contact], "must belong to the event vendor's global vendor"
  end

  test "allows a contact to be selected only once per event vendor" do
    contact = @global_vendor.contacts.first
    @event_vendor.event_vendor_contacts.create!(global_vendor_contact: contact)
    duplicate = @event_vendor.event_vendor_contacts.new(global_vendor_contact: contact)

    assert_not duplicate.valid?
    assert_includes duplicate.errors[:global_vendor_contact_id], "has already been taken"
  end

  test "assigns sequential positions" do
    first = @event_vendor.event_vendor_contacts.create!(global_vendor_contact: @global_vendor.contacts.first)
    second = @event_vendor.event_vendor_contacts.create!(global_vendor_contact: @global_vendor.contacts.second)

    assert_equal first.position + 1, second.position
    assert_equal [ first, second ], @event_vendor.event_vendor_contacts.reload.to_a
  end
end
