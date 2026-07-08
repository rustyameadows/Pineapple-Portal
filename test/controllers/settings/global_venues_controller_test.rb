require "test_helper"

module Settings
  class GlobalVenuesControllerTest < ActionDispatch::IntegrationTest
    test "admin can access global venues" do
      log_in_as(users(:two))

      get settings_global_venues_url

      assert_response :success
    end

    test "planner cannot access global venues" do
      log_in_as(users(:one))

      get settings_global_venues_url

      assert_redirected_to root_url
    end
  end
end
