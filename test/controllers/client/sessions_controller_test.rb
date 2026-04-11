require "test_helper"

module Client
  class SessionsControllerTest < ActionDispatch::IntegrationTest
    setup do
      @single_event_client = users(:client_contact)
      @single_event = events(:one)
      @secondary_event = events(:two)
      @multi_event_client = build_client_user(
        name: "Multi Event Client",
        email: "multi-event-client@example.com"
      )
      grant_client_access(@multi_event_client, @single_event)
      grant_client_access(@multi_event_client, @secondary_event)
      @unassigned_client = build_client_user(
        name: "Unassigned Client",
        email: "unassigned-client@example.com"
      )
    end

    test "shows the client login form" do
      get client_login_url

      assert_response :success
      assert_select "h1", text: "Client Portal Login"
    end

    test "guest portal requests redirect to client login with a return_to" do
      get client_event_url(@single_event.portal_slug)

      assert_redirected_to client_login_url(return_to: client_event_path(@single_event.portal_slug))

      follow_redirect!

      assert_response :success
      assert_select "input[name='return_to'][value='#{client_event_path(@single_event.portal_slug)}']"
    end

    test "renders errors on invalid client login" do
      post client_login_url, params: {
        email: "missing@example.com",
        password: "bad"
      }

      assert_response :unprocessable_content
      assert_select "p.auth-card__flash--alert", text: /Invalid email or password/
    end

    test "redirects a single-event client through the client login hub" do
      post client_login_url, params: {
        email: @single_event_client.email,
        password: "password123"
      }

      assert_redirected_to client_login_url

      follow_redirect!

      assert_redirected_to client_event_url(@single_event.portal_slug)
      follow_redirect!
      assert_response :success
      assert_select "#planning-grid"
      assert_equal @single_event_client.id, session[:client_user_id]
    end

    test "shows an event selector for a multi-event client" do
      post client_login_url, params: {
        email: @multi_event_client.email,
        password: "password123"
      }

      assert_redirected_to client_login_url

      follow_redirect!

      assert_response :success
      assert_select "h1", text: "Choose Your Event"
      assert_select "a[href='#{client_event_path(@single_event.portal_slug)}']"
      assert_select "a[href='#{client_event_path(@secondary_event.portal_slug)}']"
      assert_equal @multi_event_client.id, session[:client_user_id]
    end

    test "revisiting the client login path sends a single-event client to their portal" do
      log_in_client_portal(@single_event_client)

      get client_login_url

      assert_redirected_to client_event_url(@single_event.portal_slug)
    end

    test "revisiting the client login path shows the event selector for multi-event clients" do
      log_in_client_portal(@multi_event_client)

      get client_login_url

      assert_response :success
      assert_select "h1", text: "Choose Your Event"
      assert_select "a[href='#{client_event_path(@single_event.portal_slug)}']"
      assert_select "a[href='#{client_event_path(@secondary_event.portal_slug)}']"
    end

    test "client login honors a return_to event path" do
      post client_login_url, params: {
        email: @multi_event_client.email,
        password: "password123",
        return_to: client_event_path(@secondary_event.portal_slug)
      }

      assert_redirected_to client_login_url(return_to: client_event_path(@secondary_event.portal_slug))

      follow_redirect!

      assert_redirected_to client_event_url(@secondary_event.portal_slug)
    end

    test "client login falls back to the selector when return_to is not an accessible event" do
      hidden_event = Event.create!(name: "Hidden Event")

      post client_login_url, params: {
        email: @multi_event_client.email,
        password: "password123",
        return_to: client_event_path(hidden_event.portal_slug)
      }

      assert_redirected_to client_login_url(return_to: client_event_path(hidden_event.portal_slug))

      follow_redirect!

      assert_response :success
      assert_select "a[href='#{client_event_path(@single_event.portal_slug)}']"
      assert_select "a[href='#{client_event_path(@secondary_event.portal_slug)}']"
    end

    test "rejects a client with no linked events" do
      post client_login_url, params: {
        email: @unassigned_client.email,
        password: "password123"
      }

      assert_response :unprocessable_content
      assert_select "p.auth-card__flash--alert", text: /No events are linked to this account yet/
      assert_nil session[:client_user_id]
    end

    test "logs out via delete" do
      log_in_client_portal(@single_event_client)

      delete client_logout_url
      assert_redirected_to client_login_url
      assert_nil session[:client_user_id]
    end

    test "logs out via get fallback" do
      log_in_client_portal(@single_event_client)

      get client_logout_url
      assert_redirected_to client_login_url
      assert_nil session[:client_user_id]
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
