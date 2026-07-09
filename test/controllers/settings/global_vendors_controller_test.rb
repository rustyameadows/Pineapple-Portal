require "test_helper"

module Settings
  class GlobalVendorsControllerTest < ActionDispatch::IntegrationTest
    setup do
      log_in_as(users(:two))
    end

    test "admin can access global vendors" do
      get settings_global_vendors_url

      assert_response :success
      assert_select "td", text: "1", minimum: 2
    end

    test "admin creates a global vendor with first-class contacts" do
      assert_difference([ "GlobalVendor.count", "GlobalVendorContact.count" ], 1) do
        post settings_global_vendors_url, params: {
          global_vendor: {
            name: "New Contact Vendor",
            default_vendor_type: "Catering",
            default_social_handle: "@newcontactvendor",
            contacts_attributes: {
              "0" => {
                name: "  New Contact  ",
                email: " contact@example.test ",
                phone: " 555-1212 ",
                position: "0"
              }
            }
          }
        }
      end

      assert_redirected_to settings_global_vendors_url
      vendor = GlobalVendor.find_by!(normalized_name: "new contact vendor")
      contact = vendor.contacts.first
      assert_equal "New Contact", contact.name
      assert_equal "contact@example.test", contact.email
      assert_equal "555-1212", contact.phone
    end

    test "admin updates and removes stable contact records" do
      vendor = global_vendors(:sunshine_catering)
      contact = global_vendor_contacts(:maria_cater)
      selection = event_vendor_contacts(:catering_maria)

      assert_difference("GlobalVendorContact.count", -1) do
        assert_difference("EventVendorContact.count", -1) do
          patch settings_global_vendor_url(vendor), params: {
            global_vendor: {
              name: vendor.name,
              default_vendor_type: vendor.default_vendor_type,
              default_social_handle: vendor.default_social_handle,
              contacts_attributes: {
                "0" => {
                  id: contact.id,
                  name: contact.name,
                  position: contact.position,
                  _destroy: "1"
                }
              }
            }
          }
        end
      end

      assert_redirected_to settings_global_vendors_url
      assert_not GlobalVendorContact.exists?(contact.id)
      assert_not EventVendorContact.exists?(selection.id)
    end

    test "planner cannot access global vendors" do
      delete logout_url
      log_in_as(users(:one))

      get settings_global_vendors_url

      assert_redirected_to root_url
    end
  end
end
