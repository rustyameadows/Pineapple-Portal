require "test_helper"

module Events
  class PlanningLinksControllerTest < ActionDispatch::IntegrationTest
    setup do
      @event = events(:one)
      @user = users(:two)
      log_in_as(@user)
    end

    test "toggles planning link visibility" do
      assert @event.planning_link_enabled?("guest_list"), "expected guest_list to start enabled"

      patch toggle_event_planning_link_path(@event, "guest_list")
      assert_redirected_to client_portal_event_settings_path(@event)

      @event.reload
      assert_not @event.planning_link_enabled?("guest_list"), "expected guest_list to be disabled"

      patch toggle_event_planning_link_path(@event, "guest_list")
      assert_redirected_to client_portal_event_settings_path(@event)

      @event.reload
      assert @event.planning_link_enabled?("guest_list"), "expected guest_list to be enabled again"
    end

    test "reorders planning links" do
      planning_link = event_links(:planning_guestbook)

      tokens = [
        Event::PlanningLinkToken.built_in("guest_list"),
        Event::PlanningLinkToken.event_link(planning_link.id),
        Event::PlanningLinkToken.built_in("financials")
      ]

      @event.update!(planning_link_tokens: tokens)

      patch move_down_event_planning_links_path(@event), params: { token: Event::PlanningLinkToken.built_in("guest_list") }
      assert_redirected_to client_portal_event_settings_path(@event)

      @event.reload
      reordered_tokens = @event.planning_link_tokens

      assert_equal Event::PlanningLinkToken.event_link(planning_link.id), reordered_tokens.first,
                   "expected custom planning link to move ahead of guest list"

      patch move_up_event_planning_links_path(@event), params: { token: Event::PlanningLinkToken.built_in("financials") }
      assert_redirected_to client_portal_event_settings_path(@event)

      @event.reload
      tokens_after_move = @event.planning_link_tokens

      assert_equal Event::PlanningLinkToken.built_in("financials"), tokens_after_move[1],
                   "expected financials card to move up"
    end
  end
end
