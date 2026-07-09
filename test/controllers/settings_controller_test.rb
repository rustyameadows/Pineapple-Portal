require "test_helper"

class SettingsControllerTest < ActionDispatch::IntegrationTest
  test "admin can access account settings" do
    log_in_as(users(:two))

    get settings_url

    assert_response :success
    assert_select "h1", text: "Account Settings"
  end

  test "planner cannot access account settings" do
    log_in_as(users(:one))

    get settings_url

    assert_redirected_to root_url
  end
end
