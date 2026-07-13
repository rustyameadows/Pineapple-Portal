require "test_helper"

module Events
  class VendorOptionsControllerTest < ActionDispatch::IntegrationTest
    setup do
      @event = events(:one)
      log_in_as(users(:two))
    end

    test "returns active event vendors before non-active matches" do
      active_global = GlobalVendor.create!(name: "Active Vendor")
      inactive_global = GlobalVendor.create!(name: "Inactive Vendor")

      @event.event_vendors.create!(name: active_global.name, global_vendor: active_global, client_visible: true)
      events(:two).event_vendors.create!(name: inactive_global.name, global_vendor: inactive_global, client_visible: true)

      get event_vendor_options_url(@event), params: { q: "vendor" }, as: :json

      assert_response :success
      body = JSON.parse(response.body)
      names = body.fetch("options").map { |item| item.fetch("name") }
      assert_equal "Active Vendor", names.first
    end

    test "includes the real planning company event vendor in item options" do
      planning_company = global_vendors(:pineapple_productions)

      get event_vendor_options_url(@event), params: { q: "Pineapple" }, as: :json

      assert_response :success
      option = JSON.parse(response.body).fetch("options").find do |candidate|
        candidate.fetch("id") == planning_company.id
      end
      assert_equal planning_company.name, option.fetch("name")
      assert_equal true, option.fetch("is_active_on_event")
    end
  end
end
