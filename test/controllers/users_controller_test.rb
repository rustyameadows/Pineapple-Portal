require "test_helper"

class UsersControllerTest < ActionDispatch::IntegrationTest
  test "creates user and redirects home" do
    assert_difference("User.count") do
      post users_url, params: { user: { name: "New User", email: "new@example.com" } }
    end

    assert_redirected_to root_url
    follow_redirect!
    assert_match "User created.", @response.body
  end

  test "renders errors when invalid" do
    post users_url, params: { user: { name: "", email: "" } }

    assert_response :unprocessable_content
    assert_select "p.flash.alert", text: /can't be blank/
  end
end
