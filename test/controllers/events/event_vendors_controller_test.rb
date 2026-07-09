require "test_helper"

module Events
  class EventVendorsControllerTest < ActionDispatch::IntegrationTest
    setup do
      @event = events(:one)
      @user = users(:two)
      log_in_as(@user)
    end

    test "creates vendor with event metadata without accepting contact changes" do
      assert_difference("EventVendor.count") do
        post event_event_vendors_url(@event), params: {
          event_vendor: {
            name: "Florist Collective",
            vendor_type: " Floral ",
            client_visible: "0",
            social_handle: " @floristcollective ",
            team_meals: "  **Two vendor meals**\n\n[Menu](https://example.com/menu)  ",
            contacts_attributes: {
              "0" => {
                name: "Fiona Florist",
                email: "fiona@florist.test",
                notes: "Prefers email"
              }
            }
          }
        }
      end

      assert_redirected_to vendors_event_settings_url(@event)
      vendor = EventVendor.find_by(name: "Florist Collective")
      refute_nil vendor
      refute vendor.client_visible?
      assert_equal "Floral", vendor.vendor_type
      assert_equal "@floristcollective", vendor.social_handle
      assert_equal "**Two vendor meals**\n\n[Menu](https://example.com/menu)", vendor.team_meals
      assert_empty vendor.contacts
    end

    test "updates vendor" do
      vendor = event_vendors(:lighting)
      legacy_event_contacts = vendor.contacts_jsonb.deep_dup

      patch event_event_vendor_url(@event, vendor), params: {
        event_vendor: {
          name: "Bright Lights Co",
          vendor_type: " Lighting & Production ",
          client_visible: "1",
          social_handle: "@bright.co",
          team_meals: "Board the **shuttle** after vendor dinner.",
          contacts_attributes: {
            "0" => { name: "Leo Light", phone: "999-000-0000" }
          }
        }
      }

      assert_redirected_to vendors_event_settings_url(@event)
      vendor.reload
      assert_equal "Bright Lights Co", vendor.name
      assert vendor.client_visible?
      assert_equal "Lighting & Production", vendor.vendor_type
      assert_equal "@bright.co", vendor.social_handle
      assert_equal "Board the **shuttle** after vendor dinner.", vendor.team_meals
      assert_equal legacy_event_contacts, vendor.contacts_jsonb
      assert_empty vendor.global_vendor.contacts
    end

    test "adding an existing global vendor preserves its global profile and contacts" do
      global_vendor = GlobalVendor.create!(
        name: "Existing Floral Studio",
        default_vendor_type: "Floral",
        default_social_handle: "@existingfloral",
        contacts_jsonb: [ {
          "name" => "Fern Florist",
          "title" => "Owner",
          "email" => "fern@example.test",
          "phone" => "555-111-2222",
          "notes" => "Primary contact"
        } ]
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
            social_handle: "@eventoverride",
            client_visible: "1",
            contacts_attributes: {
              "0" => { name: "", email: "", phone: "" }
            }
          }
        }
      end

      assert_redirected_to vendors_event_settings_url(@event)
      event_vendor = @event.event_vendors.find_by!(global_vendor: global_vendor)
      assert_equal "Event Floral", event_vendor.vendor_type
      assert_equal "@eventoverride", event_vendor.social_handle
      assert_empty event_vendor.contacts_jsonb
      assert_equal original_profile, global_vendor.reload.attributes.slice(*original_profile.keys)
    end

    test "switching an event vendor preserves both global vendor profiles and contacts" do
      event_vendor = event_vendors(:lighting)
      original_global = GlobalVendor.create!(
        name: "Original Lighting Global",
        default_vendor_type: "Lighting",
        default_social_handle: "@originallighting",
        contacts_jsonb: [ { "name" => "Original Contact", "email" => "original@example.test" } ]
      )
      replacement_global = GlobalVendor.create!(
        name: "Replacement Production Global",
        default_vendor_type: "Production",
        default_social_handle: "@replacementproduction",
        contacts_jsonb: [ { "name" => "Replacement Contact", "email" => "replacement@example.test" } ]
      )
      event_vendor.update!(global_vendor: original_global)
      original_profile = original_global.attributes.slice("default_vendor_type", "default_social_handle", "contacts_jsonb", "updated_at")
      replacement_profile = replacement_global.attributes.slice("default_vendor_type", "default_social_handle", "contacts_jsonb", "updated_at")
      legacy_event_contacts = event_vendor.contacts_jsonb.deep_dup

      patch event_event_vendor_url(@event, event_vendor), params: {
        event_vendor: {
          global_vendor_id: replacement_global.id,
          name: replacement_global.name,
          vendor_type: "Event Production",
          social_handle: "@eventproduction",
          contacts_attributes: {
            "0" => { name: "Original Contact", email: "original@example.test" }
          }
        }
      }

      assert_redirected_to vendors_event_settings_url(@event)
      assert_equal replacement_global, event_vendor.reload.global_vendor
      assert_equal replacement_global.name, event_vendor.name
      assert_equal legacy_event_contacts, event_vendor.contacts_jsonb
      assert_equal original_profile, original_global.reload.attributes.slice(*original_profile.keys)
      assert_equal replacement_profile, replacement_global.reload.attributes.slice(*replacement_profile.keys)
    end

    test "saving a linked event vendor without contact changes preserves the global vendor" do
      global_vendor = GlobalVendor.create!(
        name: "Linked Catering Global",
        default_vendor_type: "Catering",
        default_social_handle: "@linkedcatering",
        contacts_jsonb: [ { "name" => "Casey Caterer", "phone" => "555-333-4444" } ]
      )
      event_vendor = event_vendors(:catering)
      event_vendor.update!(global_vendor: global_vendor)
      original_profile = global_vendor.attributes.slice("default_vendor_type", "default_social_handle", "contacts_jsonb", "updated_at")
      legacy_event_contacts = event_vendor.contacts_jsonb.deep_dup

      patch event_event_vendor_url(@event, event_vendor), params: {
        event_vendor: {
          global_vendor_id: global_vendor.id,
          name: global_vendor.name,
          vendor_type: "Event Catering",
          social_handle: "@eventcatering",
          team_meals: "Two meals"
        }
      }

      assert_redirected_to vendors_event_settings_url(@event)
      assert_equal "Two meals", event_vendor.reload.team_meals
      assert_equal legacy_event_contacts, event_vendor.contacts_jsonb
      assert_equal original_profile, global_vendor.reload.attributes.slice(*original_profile.keys)
    end

    test "reorders vendors with move_up" do
      lower_vendor = event_vendors(:lighting)
      higher_vendor = event_vendors(:catering)
      assert higher_vendor.position < lower_vendor.position

      patch move_up_event_event_vendor_url(@event, lower_vendor)

      assert_redirected_to vendors_event_settings_url(@event)
      higher_vendor.reload
      lower_vendor.reload
      assert lower_vendor.position < higher_vendor.position
    end

    test "destroys vendor" do
      vendor = event_vendors(:lighting)

      assert_difference("EventVendor.count", -1) do
        delete event_event_vendor_url(@event, vendor)
      end

      assert_redirected_to vendors_event_settings_url(@event)
    end
  end
end
