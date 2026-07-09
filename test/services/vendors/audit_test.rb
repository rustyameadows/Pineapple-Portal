require "test_helper"

module Vendors
  class AuditTest < ActiveSupport::TestCase
    test "classifies every linked vendor contact state without exposing contact data" do
      baseline = Audit.new.call.metrics

      create_linked_vendor("Equal Contacts", local: [ contact("Equal") ], global: [ contact("Equal") ])
      create_linked_vendor("Local Contacts", local: [ contact("Local") ], global: [])
      create_linked_vendor("Global Contacts", local: [], global: [ contact("Global") ])
      create_linked_vendor("Different Contacts", local: [ contact("Local Different") ], global: [ contact("Global Different") ])

      report = Audit.new.call
      metrics = report.metrics

      assert_equal baseline[:linked_contacts_equal] + 1, metrics[:linked_contacts_equal]
      assert_equal baseline[:linked_local_contacts_only] + 1, metrics[:linked_local_contacts_only]
      assert_equal baseline[:linked_global_contacts_only] + 1, metrics[:linked_global_contacts_only]
      assert_equal baseline[:linked_contacts_different] + 1, metrics[:linked_contacts_different]
      assert_equal baseline[:linked_contact_mismatches] + 3, metrics[:linked_contact_mismatches]
      assert_equal baseline[:event_vendors_with_local_contacts] + 3, metrics[:event_vendors_with_local_contacts]
      assert_report_invariants(metrics)
      refute_includes report.to_s, "Equal"
      refute_includes report.to_s, "audit@example.test"
      refute_includes report.to_s, "555-000-1111"
    end

    test "compares contacts independent of hash and contact order while retaining duplicates" do
      audit = Audit.new
      left = [ contact("Second"), contact("First"), contact("First") ]
      right = [
        { phone: "555-000-1111", email: "audit@example.test", name: " First " },
        contact("Second"),
        contact("First")
      ]

      assert_equal audit.send(:canonical_contacts, left), audit.send(:canonical_contacts, right)
      refute_equal audit.send(:canonical_contacts, left), audit.send(:canonical_contacts, right.first(2))
    end

    test "classifies ROS values only against the current event roster" do
      baseline = Audit.new.call.metrics
      event = Event.create!(name: "Vendor Audit Event")
      master = event.event_calendars.create!(name: "Audit ROS", kind: :master, timezone: "UTC")
      derived = event.event_calendars.create!(name: "Audit Derived", kind: :derived, timezone: "UTC")

      add_event_vendor(event, "Acme & Sons")
      renamed = add_event_vendor(event, "Renamed Global")
      renamed.update_column(:name, "Old Event Name") # rubocop:disable Rails/SkipsModelValidations
      event.event_vendors.create!(name: "Ambiguous Vendor")
      event.event_vendors.create!(name: "Ambiguous  Vendor")

      create_item(master, "Acme & Sons")
      create_item(master, "Renamed Global")
      create_item(master, "  acme & sons  ")
      create_item(master, "ambiguous vendor")
      create_item(master, "Mystery Company")
      create_item(master, "DJ TBD")
      create_item(master, "Acme & Sons / Renamed Global")
      create_item(master, "Acme & Sons / Unknown Rentals")
      create_item(master, "Unknown A / Unknown B")
      create_item(derived, "Renamed Global")
      create_item(derived, "   ")

      metrics = Audit.new.call.metrics

      assert_equal baseline[:calendar_items_with_vendor_value] + 10, metrics[:calendar_items_with_vendor_value]
      assert_equal baseline[:calendar_items_with_blank_vendor_value] + 1, metrics[:calendar_items_with_blank_vendor_value]
      assert_equal baseline[:ros_items_with_vendor_value] + 9, metrics[:ros_items_with_vendor_value]
      assert_equal baseline[:derived_calendar_items_with_vendor_value] + 1, metrics[:derived_calendar_items_with_vendor_value]
      assert_equal baseline[:vendor_values_exact_match] + 3, metrics[:vendor_values_exact_match]
      assert_equal baseline[:vendor_values_normalized_match] + 1, metrics[:vendor_values_normalized_match]
      assert_equal baseline[:vendor_values_ambiguous] + 1, metrics[:vendor_values_ambiguous]
      assert_equal baseline[:vendor_values_unmatched] + 5, metrics[:vendor_values_unmatched]
      assert_equal baseline[:unmatched_placeholder_values] + 1, metrics[:unmatched_placeholder_values]
      assert_equal baseline[:unmatched_suspected_multiple_values] + 3, metrics[:unmatched_suspected_multiple_values]
      assert_equal baseline[:unmatched_other_values] + 1, metrics[:unmatched_other_values]
      assert_equal baseline[:suspected_multiple_all_parts_match] + 1, metrics[:suspected_multiple_all_parts_match]
      assert_equal baseline[:suspected_multiple_some_parts_match] + 1, metrics[:suspected_multiple_some_parts_match]
      assert_equal baseline[:suspected_multiple_no_parts_match] + 1, metrics[:suspected_multiple_no_parts_match]
      assert_report_invariants(metrics)
    end

    test "reports inventory and malformed contact shapes without changing records" do
      global_vendor = GlobalVendor.create!(name: "Malformed Global")
      event_vendor = events(:two).event_vendors.create!(name: "Malformed Event Vendor")
      global_vendor.update_column(:contacts_jsonb, [ "bad", { "legacy" => "value" } ]) # rubocop:disable Rails/SkipsModelValidations
      event_vendor.update_column(:contacts_jsonb, [ "bad", { "legacy" => "value" } ]) # rubocop:disable Rails/SkipsModelValidations
      timestamps = [ global_vendor.reload.updated_at, event_vendor.reload.updated_at ]

      metrics = Audit.new.call.metrics

      assert_operator metrics[:global_vendors_total], :>=, 1
      assert_operator metrics[:event_vendors_total], :>=, 1
      assert_operator metrics[:event_vendors_unlinked], :>=, 1
      assert_operator metrics[:global_vendors_with_malformed_contact_entries], :>=, 1
      assert_operator metrics[:event_vendors_with_malformed_contact_entries], :>=, 1
      assert_operator metrics[:global_vendors_with_unknown_contact_keys], :>=, 1
      assert_operator metrics[:event_vendors_with_unknown_contact_keys], :>=, 1
      assert_equal timestamps, [ global_vendor.reload.updated_at, event_vendor.reload.updated_at ]
      assert_report_invariants(metrics)
    end

    private

    def contact(name)
      {
        "name" => name,
        "email" => "audit@example.test",
        "phone" => "555-000-1111"
      }
    end

    def create_linked_vendor(name, local:, global:)
      global_vendor = GlobalVendor.create!(name:, contacts_jsonb: global)
      events(:two).event_vendors.create!(global_vendor:, contacts_jsonb: local)
    end

    def add_event_vendor(event, name)
      global_vendor = GlobalVendor.create!(name:)
      event.event_vendors.create!(global_vendor:)
    end

    def create_item(calendar, vendor_name)
      calendar.calendar_items.create!(title: "Audit item #{calendar.calendar_items.count}", vendor_name:)
    end

    def assert_report_invariants(metrics)
      assert_equal metrics[:event_vendors_total], metrics[:event_vendors_linked] + metrics[:event_vendors_unlinked]
      assert_equal metrics[:event_vendors_linked],
                   metrics.values_at(
                     :linked_contacts_equal,
                     :linked_local_contacts_only,
                     :linked_global_contacts_only,
                     :linked_contacts_different
                   ).sum
      assert_equal metrics[:calendar_items_with_vendor_value],
                   metrics.values_at(
                     :vendor_values_exact_match,
                     :vendor_values_normalized_match,
                     :vendor_values_ambiguous,
                     :vendor_values_unmatched
                   ).sum
      assert_equal metrics[:vendor_values_unmatched],
                   metrics.values_at(
                     :unmatched_placeholder_values,
                     :unmatched_suspected_multiple_values,
                     :unmatched_other_values
                   ).sum
      assert_equal metrics[:unmatched_suspected_multiple_values],
                   metrics.values_at(
                     :suspected_multiple_all_parts_match,
                     :suspected_multiple_some_parts_match,
                     :suspected_multiple_no_parts_match
                   ).sum
    end
  end
end
