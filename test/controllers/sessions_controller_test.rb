require "test_helper"

class SessionsControllerTest < ActionDispatch::IntegrationTest
  test "shows login form" do
    get login_url
    assert_response :success
    assert_select "h1", text: "Log In"
    assert_select "a[href='#{client_login_path}']"
  end

  test "logs in with valid credentials" do
    user = users(:one)

    post login_url, params: { email: user.email, password: "password123" }

    assert_redirected_to root_url
    follow_redirect!
    assert_select "div.flash.flash-notice", text: /Welcome back/
  end

  test "redirects client users to the client login path" do
    client = users(:client_contact)

    post login_url, params: { email: client.email, password: "password123" }

    assert_redirected_to client_login_url
    assert_nil session[:user_id]
    assert_nil session[:client_user_id]
  end

  test "rejects contact-only planner accounts from internal login" do
    contact = users(:planner_two)
    contact.update!(account_kind: User::ACCOUNT_KINDS[:contact])

    post login_url, params: { email: contact.email, password: "password123" }

    assert_response :unprocessable_content
    assert_nil session[:user_id]
    assert_select "p.auth-card__flash--alert", text: /Invalid email or password/
  end

  test "renders errors on invalid login" do
    post login_url, params: { email: "missing@example.com", password: "bad" }

    assert_response :unprocessable_content
    assert_select "p.auth-card__flash--alert", text: /Invalid email or password/
  end

  test "logs out" do
    user = users(:one)
    post login_url, params: { email: user.email, password: "password123" }

    delete logout_url

    assert_redirected_to login_url
    follow_redirect!
    assert_select "p.auth-card__flash--notice", text: /Logged out/
  end
end
