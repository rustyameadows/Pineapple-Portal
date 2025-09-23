require "test_helper"

class UsersControllerTest < ActionDispatch::IntegrationTest
  test "signed-in user can create another user" do
    log_in(users(:one))

    assert_difference("User.count") do
      post users_url, params: { user: {
        name: "New User",
        email: "new@example.com",
        password: "password123",
        password_confirmation: "password123"
      } }
    end

    assert_redirected_to users_url
    follow_redirect!
    assert_select "div.flash.flash-notice", text: "User created."
    assert_select "tbody tr td", text: "New User"
  end

  test "renders errors when invalid for signed-in user" do
    log_in(users(:one))

    post users_url, params: { user: { name: "", email: "", password: "", password_confirmation: "" } }

    assert_response :unprocessable_content
    assert_select "div.flash.flash-alert", text: /can't be blank/
  end

  test "first user can sign up without prior login" do
    User.delete_all

    assert_difference("User.count") do
      post users_url, params: { user: {
        name: "First User",
        email: "first@example.com",
        password: "password123",
        password_confirmation: "password123"
      } }
    end

    assert_redirected_to root_url
    follow_redirect!
    assert_select "div.flash.flash-notice", text: "Welcome aboard!"
  end

  private

  def log_in(user)
    post login_url, params: { email: user.email, password: "password123" }
  end
end
