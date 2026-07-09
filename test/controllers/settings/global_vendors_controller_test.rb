require "test_helper"

module Settings
  class GlobalVendorsControllerTest < ActionDispatch::IntegrationTest
    test "admin can access global vendors" do
      log_in_as(users(:two))

      get settings_global_vendors_url

      assert_response :success
    end

    test "planner cannot access global vendors" do
      log_in_as(users(:one))

      get settings_global_vendors_url

      assert_redirected_to root_url
    end
  end
end
