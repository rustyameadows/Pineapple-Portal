require "test_helper"

module Client
  class PasswordResetsControllerTest < ActionDispatch::IntegrationTest
    setup do
      @token = password_reset_tokens(:client_one_active)
    end

    test "renders reset form for active token" do
      get client_password_reset_path(@token.token)
      assert_response :success
      assert_select "h1", text: "Reset Portal Password"
      assert_select "strong", text: users(:client_contact).name
    end

    test "updates password and redeems token" do
      patch client_password_reset_path(@token.token), params: {
        password_reset: {
          password: "newpassword",
          password_confirmation: "newpassword"
        }
      }

      assert_redirected_to client_event_path(events(:one))
      @token.reload
      assert @token.redeemed_at.present?
      assert_equal users(:client_contact).id, session[:client_user_id]
      assert users(:client_contact).reload.authenticate("newpassword")
    end

    test "shows message for already used token" do
      expired = password_reset_tokens(:client_one_expired)

      get client_password_reset_path(expired.token)
      assert_response :success
      assert_select "p", text: /expired or was already used/i
    end

    test "cannot update with expired token" do
      expired = password_reset_tokens(:client_one_expired)

      patch client_password_reset_path(expired.token), params: {
        password_reset: {
          password: "newpassword",
          password_confirmation: "newpassword"
        }
      }

      assert_response :unprocessable_content
      assert_select "p", text: /reset link has expired/i
    end
  end
end
