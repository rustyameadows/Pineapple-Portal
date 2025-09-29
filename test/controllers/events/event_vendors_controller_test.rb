require "test_helper"

module Events
  class EventVendorsControllerTest < ActionDispatch::IntegrationTest
    setup do
      @event = events(:one)
      @user = users(:two)
      log_in_as(@user)
    end

    test "creates vendor with contacts" do
      assert_difference("EventVendor.count") do
        post event_event_vendors_url(@event), params: {
          event_vendor: {
            name: "Florist Collective",
            vendor_type: " Floral ",
            client_visible: "0",
            social_handle: " @floristcollective ",
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
      assert_equal [{
        "name" => "Fiona Florist",
        "title" => nil,
        "email" => "fiona@florist.test",
        "phone" => nil,
        "notes" => "Prefers email"
      }], vendor.contacts
    end

    test "updates vendor" do
      vendor = event_vendors(:lighting)

      patch event_event_vendor_url(@event, vendor), params: {
        event_vendor: {
          name: "Bright Lights Co",
          vendor_type: " Lighting & Production ",
          client_visible: "1",
          social_handle: "@bright.co",
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
      assert_equal "999-000-0000", vendor.contacts.first["phone"]
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
