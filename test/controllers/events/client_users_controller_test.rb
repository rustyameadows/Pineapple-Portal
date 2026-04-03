require "test_helper"

module Events
  class ClientUsersControllerTest < ActionDispatch::IntegrationTest
    setup do
      @event = events(:one)
      @client_member = event_team_members(:client_one)
      @client_user = @client_member.user
      log_in_as(users(:two))
    end

    test "linked client can load edit page" do
      get edit_event_client_user_url(@event, @client_user)

      assert_response :success
      assert_select "input[name='user[name]']", count: 1
      assert_select "input[name='user[email]']", count: 1
      assert_select "input[type='checkbox'][name='user[can_view_financials]']", count: 1
      assert_select "select[name='user[role]']", count: 0
      assert_select "select[name='user[account_kind]']", count: 0
    end

    test "update succeeds and redirects back to client access" do
      patch event_client_user_url(@event, @client_user), params: {
        user: {
          name: "Updated Client",
          email: "updated_client@example.com",
          phone_number: "555-101-2020",
          can_view_financials: "1"
        },
        return_to: clients_event_settings_path(@event)
      }

      assert_redirected_to clients_event_settings_url(@event)

      @client_user.reload
      assert_equal "Updated Client", @client_user.name
      assert_equal "updated_client@example.com", @client_user.email
      assert_equal "555-101-2020", @client_user.phone_number
      assert @client_user.can_view_financials?
    end

    test "non-member client id is rejected" do
      get edit_event_client_user_url(@event, users(:client_two))

      assert_response :not_found
    end

    test "inline financial access patch flips true and false" do
      refute @client_user.can_view_financials?

      patch event_client_user_url(@event, @client_user), params: {
        user: { can_view_financials: "1" },
        return_to: clients_event_settings_path(@event)
      }

      assert_redirected_to clients_event_settings_url(@event)
      assert @client_user.reload.can_view_financials?

      patch event_client_user_url(@event, @client_user), params: {
        user: { can_view_financials: "0" },
        return_to: clients_event_settings_path(@event)
      }

      assert_redirected_to clients_event_settings_url(@event)
      refute @client_user.reload.can_view_financials?
    end
  end
end
