require "test_helper"

class WelcomeControllerTest < ActionDispatch::IntegrationTest
  test "redirects guests to login" do
    get root_url
    assert_redirected_to login_url
  end

  test "loads home when signed in" do
    post login_url, params: { email: users(:one).email, password: "password123" }

    get root_url
    assert_response :success
    assert_select "h1", text: "Your Active Events"
  end
end
