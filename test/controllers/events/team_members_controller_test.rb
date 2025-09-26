require "test_helper"

module Events
  class TeamMembersControllerTest < ActionDispatch::IntegrationTest
    setup do
      @event = events(:one)
      log_in_as(users(:two))
    end

    test "adds planner to event team" do
      assert_difference("EventTeamMember.count") do
        post event_team_members_url(@event), params: {
          event_team_member: {
            user_id: users(:planner_two).id
          }
        }
      end

      assert_redirected_to event_settings_url(@event)
      team_member = EventTeamMember.find_by(event: @event, user: users(:planner_two))
      assert team_member.client_visible?
      assert_equal EventTeamMember.where(event: @event).maximum(:position), team_member.position
    end

    test "cannot add non planner" do
      assert_no_difference("EventTeamMember.count") do
        post event_team_members_url(@event), params: {
          event_team_member: {
            user_id: users(:client_contact).id
          }
        }
      end

      assert_redirected_to event_settings_url(@event)
      assert_match "must be a planner", flash[:alert]
    end

    test "updates visibility" do
      member = event_team_members(:two)

      patch event_team_member_url(@event, member), params: {
        event_team_member: { client_visible: "1" }
      }

      assert_redirected_to event_settings_url(@event)
      assert member.reload.client_visible?
    end

    test "updates lead planner" do
      member = event_team_members(:two)

      refute member.lead_planner?

      patch event_team_member_url(@event, member), params: {
        event_team_member: { lead_planner: "1" }
      }

      assert_redirected_to event_settings_url(@event)
      assert member.reload.lead_planner?
    end

    test "updates position" do
      member = event_team_members(:two)

      patch event_team_member_url(@event, member), params: {
        event_team_member: { position: "5" }
      }

      assert_redirected_to event_settings_url(@event)
      assert_equal 5, member.reload.position
    end

    test "removes team member" do
      member = event_team_members(:one)

      assert_difference("EventTeamMember.count", -1) do
        delete event_team_member_url(@event, member)
      end

      assert_redirected_to event_settings_url(@event)
    end
  end
end
