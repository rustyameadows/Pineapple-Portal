require "test_helper"

module Client
  class EventsControllerTest < ActionDispatch::IntegrationTest
    setup do
      @event = events(:one)
      log_in_as(users(:two))
    end

    test "planning grid shows built-in and custom planning links" do
      @event.reload
      get client_event_url(@event)

      assert_response :success
      assert_select "#planning-grid h3", text: "Guest List"
      assert_select "#planning-grid h3", text: "Guest Book"
    end

    test "planning grid hides disabled built-in planning links" do
      @event.disable_planning_link("guest_list")
      @event.save!
      @event.reload

      get client_event_url(@event)

      assert_response :success
      assert_select "#planning-grid h3", text: "Guest List", count: 0
    end

    test "planning grid respects custom ordering" do
      planning_link = event_links(:planning_guestbook)

      tokens = [
        Event::PlanningLinkToken.event_link(planning_link.id),
        Event::PlanningLinkToken.built_in("guest_list")
      ]

      @event.update!(planning_link_tokens: tokens)

      get client_event_url(@event)

      assert_response :success
      assert_select "#planning-grid .client-planning-grid__card:nth-child(1) h3", text: "Guest Book"
      assert_select "#planning-grid .client-planning-grid__card:nth-child(2) h3", text: "Guest List"
    end

    test "portal slug resolves to event" do
      get client_event_url(@event.portal_slug)

      assert_response :success
      assert_select "#planning-grid"
    end
  end
end
