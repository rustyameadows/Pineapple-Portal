require "test_helper"

module Events
  class TeamMembersControllerTest < ActionDispatch::IntegrationTest
    setup do
      @event = events(:one)
      log_in_as(users(:two))
    end

    test "adds planner to event team" do
      post event_team_members_url(@event), params: {
        event_team_member: {
          user_id: users(:planner_two).id
        }
      }

      assert_redirected_to planners_event_settings_url(@event)
      team_member = EventTeamMember.find_by(event: @event, user: users(:planner_two))
      assert_not_nil team_member
      assert team_member.client_visible?
      assert_equal EventTeamMember.where(event: @event).maximum(:position), team_member.position
      assert_equal "planner", team_member.member_role
    end

    test "cannot add client as planner" do
      assert_no_difference("EventTeamMember.count") do
        post event_team_members_url(@event), params: {
          event_team_member: {
            user_id: users(:client_contact).id,
            member_role: "planner"
          }
        }
      end

      assert_redirected_to planners_event_settings_url(@event)
      assert_match "must be a planner or admin", flash[:alert]
    end

    test "updates visibility" do
      member = event_team_members(:two)

      patch event_team_member_url(@event, member), params: {
        event_team_member: { client_visible: "1" }
      }

      assert_redirected_to planners_event_settings_url(@event)
      assert member.reload.client_visible?
    end

    test "adds client to event" do
      assert_difference("EventTeamMember.count") do
        post event_team_members_url(@event), params: {
          event_team_member: {
            user_id: users(:client_two).id,
            member_role: "client"
          }
        }
      end

      assert_redirected_to clients_event_settings_url(@event)
      team_member = EventTeamMember.find_by(event: @event, user: users(:client_two))
      assert_equal "client", team_member.member_role
      assert team_member.client_visible?
    end

    test "updates lead planner" do
      member = event_team_members(:two)

      refute member.lead_planner?

      patch event_team_member_url(@event, member), params: {
        event_team_member: { lead_planner: "1" }
      }

      assert_redirected_to planners_event_settings_url(@event)
      assert member.reload.lead_planner?
    end

    test "updates position" do
      member = event_team_members(:two)

      patch event_team_member_url(@event, member), params: {
        event_team_member: { position: "5" }
      }

      assert_redirected_to planners_event_settings_url(@event)
      assert_equal 5, member.reload.position
    end

    test "deactivates client access" do
      member = event_team_members(:client_one)
      assert member.client_visible?

      patch event_team_member_url(@event, member), params: {
        event_team_member: { client_visible: "0" }
      }

      assert_redirected_to clients_event_settings_url(@event)
      refute member.reload.client_visible?
    end

    test "removes team member" do
      member = event_team_members(:one)

      assert_difference("EventTeamMember.count", -1) do
        delete event_team_member_url(@event, member)
      end

      assert_redirected_to planners_event_settings_url(@event)
    end

    test "generates reset token for client" do
      member = event_team_members(:client_one)

      assert_difference("PasswordResetToken.count", 1) do
        post issue_reset_event_team_member_url(@event, member)
      end

      assert_redirected_to clients_event_settings_url(@event)
      token = PasswordResetToken.order(:created_at).last
      assert_equal member.user, token.user
      assert token.expires_at > Time.current
    end

    test "rejects reset generation for planner" do
      member = event_team_members(:two)

      assert_no_difference("PasswordResetToken.count") do
        post issue_reset_event_team_member_url(@event, member)
      end

      assert_redirected_to planners_event_settings_url(@event)
      assert_match "only available for client accounts", flash[:alert]
    end
  end
end
