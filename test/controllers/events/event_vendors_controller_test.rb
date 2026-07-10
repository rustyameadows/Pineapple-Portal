require "test_helper"

module Events
  class EventVendorsControllerTest < ActionDispatch::IntegrationTest
    setup do
      @event = events(:one)
      log_in_as(users(:two))
    end

    test "explicitly creates a global vendor and adds it to the event" do
      assert_difference([ "GlobalVendor.count", "EventVendor.count" ], 1) do
        post event_event_vendors_url(@event), params: {
          event_vendor: {
            name: "Florist Collective",
            create_global_vendor: "1",
            vendor_type: " Floral ",
            client_visible: "0",
            team_meals: "  **Two vendor meals**\n\n[Menu](https://example.com/menu)  "
          }
        }
      end

      assert_redirected_to vendors_event_settings_url(@event)
      global_vendor = GlobalVendor.find_by!(normalized_name: "florist collective")
      vendor = @event.event_vendors.find_by!(global_vendor:)
      assert_equal "Florist Collective", vendor.name
      assert_equal "Floral", vendor.vendor_type
      refute vendor.client_visible?
      assert_equal "**Two vendor meals**\n\n[Menu](https://example.com/menu)", vendor.team_meals
      assert_empty vendor.contacts
    end

    test "requires an existing selection or explicit global creation" do
      assert_no_difference([ "GlobalVendor.count", "EventVendor.count" ]) do
        post event_event_vendors_url(@event), params: {
          event_vendor: { name: "Unconfirmed Vendor", vendor_type: "Floral" }
        }
      end

      assert_redirected_to vendors_event_settings_url(@event)
      assert_equal "Global vendor must be selected from the global library or explicitly created", flash[:alert]
    end

    test "adds an existing global vendor with all contacts selected by default" do
      global_vendor = GlobalVendor.create!(
        name: "Existing Floral Studio",
        default_vendor_type: "Floral",
        default_social_handle: "@existingfloral",
        contacts_jsonb: [ { "name" => "Legacy Contact", "email" => "legacy@example.test" } ],
        contacts_attributes: {
          "0" => { name: "Fern Florist", email: "fern@example.test" },
          "1" => { name: "Faye Florist", email: "faye@example.test" }
        }
      )
      original_profile = global_vendor.attributes.slice(
        "name",
        "normalized_name",
        "default_vendor_type",
        "default_social_handle",
        "contacts_jsonb",
        "updated_at"
      )

      assert_no_difference("GlobalVendor.count") do
        post event_event_vendors_url(@event), params: {
          event_vendor: {
            global_vendor_id: global_vendor.id,
            name: global_vendor.name,
            vendor_type: "Event Floral",
            client_visible: "1"
          }
        }
      end

      assert_redirected_to vendors_event_settings_url(@event)
      event_vendor = @event.event_vendors.find_by!(global_vendor:)
      assert_equal "Event Floral", event_vendor.vendor_type
      assert_equal "@existingfloral", event_vendor.social_handle
      assert_equal global_vendor.contact_ids, event_vendor.selected_contact_ids
      assert_empty event_vendor.contacts_jsonb
      assert_equal original_profile, global_vendor.reload.attributes.slice(*original_profile.keys)
    end

    test "updates event metadata and selected contacts without changing canonical profile data" do
      vendor = event_vendors(:lighting)
      selected = vendor.global_vendor.contacts.first
      extra = vendor.global_vendor.contacts.create!(name: "Lighting Producer", email: "producer@example.test")
      legacy_event_contacts = vendor.contacts_jsonb.deep_dup
      original_global_profile = vendor.global_vendor.attributes.slice(
        "name",
        "normalized_name",
        "default_vendor_type",
        "default_social_handle",
        "contacts_jsonb",
        "updated_at"
      )

      patch event_event_vendor_url(@event, vendor), params: {
        event_vendor: {
          name: "Ignored Event Name",
          global_vendor_id: vendor.global_vendor_id,
          vendor_type: " Lighting & Production ",
          social_handle: "@ignored-event-social",
          client_visible: "1",
          team_meals: "Board the **shuttle** after vendor dinner.",
          global_vendor_contact_ids: [ extra.id ]
        }
      }

      assert_redirected_to vendors_event_settings_url(@event)
      vendor.reload
      assert_equal vendor.global_vendor.name, vendor.name
      assert_equal vendor.global_vendor.default_social_handle, vendor.social_handle
      assert vendor.client_visible?
      assert_equal "Lighting & Production", vendor.vendor_type
      assert_equal "Board the **shuttle** after vendor dinner.", vendor.team_meals
      assert_equal [ extra.id ], vendor.selected_contact_ids
      refute_includes vendor.selected_contact_ids, selected.id
      assert_equal legacy_event_contacts, vendor.contacts_jsonb
      assert_equal original_global_profile, vendor.global_vendor.reload.attributes.slice(*original_global_profile.keys)
    end

    test "clears all event contact selections" do
      vendor = event_vendors(:catering)
      assert vendor.selected_contacts.any?

      patch event_event_vendor_url(@event, vendor), params: {
        event_vendor: {
          vendor_type: vendor.vendor_type,
          global_vendor_contact_ids: [ "" ]
        }
      }

      assert_redirected_to vendors_event_settings_url(@event)
      assert_empty vendor.reload.selected_contacts
    end

    test "rejects a contact from another global vendor without partially updating" do
      vendor = event_vendors(:catering)
      original_type = vendor.vendor_type
      original_contact_ids = vendor.selected_contact_ids
      foreign_contact = global_vendor_contacts(:leo_light)

      patch event_event_vendor_url(@event, vendor), params: {
        event_vendor: {
          vendor_type: "Should Roll Back",
          global_vendor_contact_ids: [ foreign_contact.id ]
        }
      }

      assert_redirected_to vendors_event_settings_url(@event)
      assert_equal original_type, vendor.reload.vendor_type
      assert_equal original_contact_ids, vendor.selected_contact_ids
      assert_match(/do not belong to this vendor/i, flash[:alert])
    end

    test "does not allow an existing event vendor to switch global vendors" do
      event_vendor = event_vendors(:lighting)
      original_global = event_vendor.global_vendor
      replacement_global = GlobalVendor.create!(name: "Replacement Production Global")

      patch event_event_vendor_url(@event, event_vendor), params: {
        event_vendor: {
          global_vendor_id: replacement_global.id,
          name: replacement_global.name,
          vendor_type: "Event Production"
        }
      }

      assert_redirected_to vendors_event_settings_url(@event)
      assert_equal original_global, event_vendor.reload.global_vendor
      assert_equal original_global.name, event_vendor.name
      assert_equal "Event Production", event_vendor.vendor_type
    end

    test "saving without contact parameters preserves existing selections" do
      event_vendor = event_vendors(:catering)
      original_contact_ids = event_vendor.selected_contact_ids

      patch event_event_vendor_url(@event, event_vendor), params: {
        event_vendor: {
          vendor_type: "Event Catering",
          team_meals: "Two meals"
        }
      }

      assert_redirected_to vendors_event_settings_url(@event)
      assert_equal "Two meals", event_vendor.reload.team_meals
      assert_equal original_contact_ids, event_vendor.selected_contact_ids
    end

    test "reorders vendors with move_up" do
      lower_vendor = event_vendors(:lighting)
      higher_vendor = event_vendors(:catering)
      planning_vendor = event_vendors(:pineapple_one)
      higher_vendor.update!(position: 0)
      planning_vendor.update!(position: 1)
      lower_vendor.update!(position: 2)
      assert higher_vendor.position < lower_vendor.position

      patch move_up_event_event_vendor_url(@event, lower_vendor)

      assert_redirected_to vendors_event_settings_url(@event)
      assert lower_vendor.reload.position < higher_vendor.reload.position
      assert_equal 1, planning_vendor.reload.position
    end

    test "does not expose the planning company event profile to direct updates" do
      planning_vendor = event_vendors(:pineapple_one)
      original_type = planning_vendor.vendor_type

      patch event_event_vendor_url(@event, planning_vendor), params: {
        event_vendor: { vendor_type: "Hidden override" }
      }

      assert_redirected_to vendors_event_settings_url(@event)
      assert_equal original_type, planning_vendor.reload.vendor_type
      assert_match(/managed by the Pineapple planning section/i, flash[:alert])
    end

    test "destroys vendor and its contact selections" do
      vendor = event_vendors(:lighting)
      selection_count = vendor.event_vendor_contacts.count

      assert_difference("EventVendor.count", -1) do
        assert_difference("EventVendorContact.count", -selection_count) do
          delete event_event_vendor_url(@event, vendor)
        end
      end

      assert_redirected_to vendors_event_settings_url(@event)
    end

    test "does not remove the planning company from an event" do
      planning_vendor = event_vendors(:pineapple_one)

      assert_no_difference("EventVendor.count") do
        delete event_event_vendor_url(@event, planning_vendor)
      end

      assert_redirected_to vendors_event_settings_url(@event)
      assert planning_vendor.reload.persisted?
      assert_match(/planning company must remain associated/i, flash[:alert])
    end
  end
end
