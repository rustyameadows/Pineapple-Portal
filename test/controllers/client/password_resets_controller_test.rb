require "test_helper"

module Client
  class PasswordResetsControllerTest < ActionDispatch::IntegrationTest
    setup do
      @token = password_reset_tokens(:client_one_active)
      @single_event = events(:one)
      @secondary_event = events(:two)
    end

    test "renders reset form for active token" do
      get client_password_reset_path(@token.token)
      assert_response :success
      assert_select "h1", text: "Reset Portal Password"
      assert_select "strong", text: users(:client_contact).name
    end

    test "updates password and routes a single-event client through the client login hub" do
      patch client_password_reset_path(@token.token), params: {
        password_reset: {
          password: "newpassword",
          password_confirmation: "newpassword"
        }
      }

      assert_redirected_to client_login_url

      follow_redirect!

      assert_redirected_to client_event_url(@single_event.portal_slug)
      follow_redirect!
      assert_response :success
      assert_select "#planning-grid"
      @token.reload
      assert @token.redeemed_at.present?
      assert_equal users(:client_contact).id, session[:client_user_id]
      assert users(:client_contact).reload.authenticate("newpassword")
    end

    test "updates password and honors a client portal return_to path" do
      return_to = client_event_calendar_path(@single_event.portal_slug, "run-of-show")

      patch client_password_reset_path(@token.token), params: {
        return_to: return_to,
        password_reset: {
          password: "newpassword",
          password_confirmation: "newpassword"
        }
      }

      assert_redirected_to client_login_url(return_to: return_to)

      follow_redirect!

      assert_redirected_to return_to
    end

    test "updates password and shows the selector for a multi-event client" do
      client = build_client_user(
        name: "Multi Event Reset Client",
        email: "multi-event-reset-client@example.com"
      )
      grant_client_access(client, @single_event)
      grant_client_access(client, @secondary_event)
      token = PasswordResetToken.generate_for!(user: client, issued_by: users(:one))

      patch client_password_reset_path(token.token), params: {
        password_reset: {
          password: "newpassword",
          password_confirmation: "newpassword"
        }
      }

      assert_redirected_to client_login_url

      follow_redirect!

      assert_response :success
      assert_select "h1", text: "Choose Your Event"
      assert_select "a[href='#{client_event_path(@single_event.portal_slug)}']"
      assert_select "a[href='#{client_event_path(@secondary_event.portal_slug)}']"
      assert_equal client.id, session[:client_user_id]
      assert client.reload.authenticate("newpassword")
      token.reload
      assert token.redeemed_at.present?
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

    private

    def build_client_user(name:, email:)
      User.create!(
        name: name,
        email: email,
        role: :client,
        password: "password123",
        password_confirmation: "password123"
      )
    end

    def grant_client_access(user, event)
      event.event_team_members.create!(
        user: user,
        member_role: EventTeamMember::TEAM_ROLES[:client],
        client_visible: true,
        lead_planner: false
      )
    end
  end
end
