require "test_helper"

class GlobalVendorContactTest < ActiveSupport::TestCase
  setup do
    @global_vendor = GlobalVendor.create!(name: "Contact Model Vendor")
  end

  test "normalizes fields and exposes a hash-compatible representation" do
    contact = @global_vendor.contacts.create!(
      name: "  Avery Contact  ",
      title: "  Producer  ",
      email: "  avery@example.test  ",
      phone: "  555-1234  ",
      notes: "  Calls first  "
    )

    assert_equal "Avery Contact", contact["name"]
    assert_equal "Producer", contact.title
    assert_equal "avery@example.test", contact.email
    assert_equal "555-1234", contact.phone
    assert_equal "Calls first", contact.notes
    assert_equal(
      {
        "name" => "Avery Contact",
        "title" => "Producer",
        "email" => "avery@example.test",
        "phone" => "555-1234",
        "notes" => "Calls first"
      },
      contact.to_h
    )
  end

  test "requires at least one contact detail" do
    contact = @global_vendor.contacts.new(name: " ", email: " ")

    assert_not contact.valid?
    assert_includes contact.errors[:base], "Contact must include at least one detail"
  end

  test "assigns sequential positions and orders contacts consistently" do
    first = @global_vendor.contacts.create!(name: "First")
    second = @global_vendor.contacts.create!(name: "Second")

    assert_equal first.position + 1, second.position
    assert_equal [ first, second ], @global_vendor.contacts.reload.to_a
  end

  test "cannot move a selected contact to a different global vendor" do
    contact = @global_vendor.contacts.create!(name: "Selected Contact")
    event_vendor = events(:one).event_vendors.create!(global_vendor: @global_vendor)
    event_vendor.replace_contact_ids!([ contact.id ])
    other_global_vendor = GlobalVendor.create!(name: "Other Contact Owner")

    contact.global_vendor = other_global_vendor

    assert_not contact.valid?
    assert_includes contact.errors[:global_vendor], "must match every event vendor that selects this contact"
  end
end
