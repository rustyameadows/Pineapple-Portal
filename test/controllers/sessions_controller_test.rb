require "test_helper"

class SessionsControllerTest < ActionDispatch::IntegrationTest
  test "shows login form" do
    get login_url
    assert_response :success
    assert_select "h1", text: "Log In"
  end

  test "logs in with valid credentials" do
    user = users(:one)

    post login_url, params: { email: user.email, password: "password123" }

    assert_redirected_to root_url
    follow_redirect!
    assert_select "div.flash-notice", text: /Welcome back/
  end

  test "renders errors on invalid login" do
    post login_url, params: { email: "missing@example.com", password: "bad" }

    assert_response :unprocessable_content
    assert_select "div.flash-alert", text: /Invalid email or password/
  end

  test "logs out" do
    user = users(:one)
    post login_url, params: { email: user.email, password: "password123" }

    delete logout_url

    assert_redirected_to login_url
    follow_redirect!
    assert_select "div.flash-notice", text: /Logged out/
  end
end
