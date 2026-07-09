require "test_helper"

class GlobalVendorTest < ActiveSupport::TestCase
  test "creates, updates, and removes first-class contacts through nested attributes" do
    global_vendor = GlobalVendor.create!(
      name: "Nested Contacts Vendor",
      contacts_attributes: {
        "0" => { name: "  Sam Vendor  ", email: " sam@example.test " },
        "1" => { name: " ", email: " " }
      }
    )

    assert_equal 1, global_vendor.contacts.count
    contact = global_vendor.contacts.first
    assert_equal "Sam Vendor", contact.name
    assert_equal "sam@example.test", contact.email

    global_vendor.update!(
      contacts_attributes: {
        "0" => { id: contact.id, name: "Samuel Vendor", email: "sam@example.test" }
      }
    )
    assert_equal "Samuel Vendor", contact.reload.name

    global_vendor.update!(contacts_attributes: { "0" => { id: contact.id, _destroy: "1" } })
    assert_empty global_vendor.contacts.reload
  end

  test "does not allow deletion while it is used by an event vendor" do
    global_vendor = GlobalVendor.create!(name: "Used Global Vendor")
    events(:one).event_vendors.create!(global_vendor:)

    assert_not global_vendor.destroy
    assert_includes global_vendor.errors[:base], "Cannot delete record because dependent event vendors exist"
  end

  test "updates no longer enqueue the broad event refresh job" do
    event = events(:one)
    global_vendor = GlobalVendor.create!(
      name: "Global Vendor",
      default_vendor_type: "Catering",
      default_social_handle: "globalvendor",
      contacts_attributes: {
        "0" => {
          name: "Sam Vendor",
          title: "Producer",
          email: "sam@globalvendor.test",
          phone: "555-111-0000",
          notes: "Primary"
        }
      }
    )

    event.event_vendors.create!(
      global_vendor: global_vendor,
      position: 7,
      client_visible: false
    )

    enqueued_event_ids = []

    Documents::Generated::RefreshEventPacketCachesJob.stub :perform_later, ->(event_id) { enqueued_event_ids << event_id } do
      global_vendor.update!(default_social_handle: "updatedvendor")
    end

    assert_equal [], enqueued_event_ids
  end
end
