require "test_helper"

class UsersControllerTest < ActionDispatch::IntegrationTest
  test "signed-in user can create another user" do
    log_in(users(:one))

    assert_difference("User.count") do
      post users_url, params: { user: {
        name: "New User",
        title: "Coordinator",
        phone_number: "555-000-1111",
        email: "new@example.com",
        password: "password123",
        password_confirmation: "password123"
      } }
    end

    assert_redirected_to users_url
    follow_redirect!
    assert_select "div.flash.flash-notice", text: /User created\./
    assert_select "tbody tr td", text: "New User"
    assert_equal "planner", User.find_by(email: "new@example.com").role
  end

  test "renders errors when invalid for signed-in user" do
    log_in(users(:one))

    post users_url, params: { user: { name: "", email: "", password: "", password_confirmation: "" } }

    assert_response :unprocessable_content
    assert_select "div.flash.flash-alert", text: /can't be blank/
  end

  test "first user can sign up without prior login" do
    CalendarItemTeamMember.delete_all
    EventTeamMember.delete_all
    PasswordResetToken.delete_all
    User.delete_all

    assert_difference("User.count") do
      post users_url, params: { user: {
        name: "First User",
        title: "Owner",
        phone_number: "555-222-3333",
        email: "first@example.com",
        password: "password123",
        password_confirmation: "password123"
      } }
    end

    assert_redirected_to root_url
    follow_redirect!
    assert_select "div.flash.flash-notice", text: /Welcome aboard!/
    assert_equal "admin", User.find_by(email: "first@example.com").role
  end

  test "admin can update user" do
    log_in(users(:two))
    user = users(:one)

    patch user_url(user), params: { user: {
      title: "Senior Planner",
      phone_number: "555-777-0000",
      role: "admin"
    } }

    assert_redirected_to users_url
    user.reload
    assert_equal "Senior Planner", user.title
    assert_equal "555-777-0000", user.phone_number
    assert_equal "admin", user.role
  end

  test "planner cannot elevate role" do
    log_in(users(:one))
    user = users(:planner_two)

    patch user_url(user), params: { user: { role: "admin" } }

    assert_redirected_to users_url
    assert_equal "planner", user.reload.role
  end

  private

  def log_in(user)
    post login_url, params: { email: user.email, password: "password123" }
  end
end
