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
      assert_select "#planning-grid h3", text: "Packets"
      assert_select "#planning-grid h3", text: "Approvals"
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

    test "planning grid hides packets when disabled" do
      @event.disable_planning_link("packets")
      @event.save!
      @event.reload

      get client_event_url(@event)

      assert_response :success
      assert_select "#planning-grid h3", text: "Packets", count: 0
    end

    test "planning grid hides approvals when disabled" do
      @event.disable_planning_link("approvals")
      @event.save!
      @event.reload

      get client_event_url(@event)

      assert_response :success
      assert_select "#planning-grid h3", text: "Approvals", count: 0
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

    test "portal layout shows a choose another event link for multi-event clients" do
      delete logout_url
      client = build_client_user(
        name: "Multi Event Client",
        email: "multi-event-layout-client@example.com"
      )
      grant_client_access(client, @event)
      grant_client_access(client, events(:two))

      log_in_client_portal(client)

      get client_event_url(@event.portal_slug)

      assert_response :success
      assert_select "a[href='#{client_login_path}']", text: /Choose another event/i
    end

    test "portal layout hides the choose another event link for single-event clients" do
      delete logout_url
      log_in_client_portal(users(:client_contact))

      get client_event_url(@event.portal_slug)

      assert_response :success
      assert_select "a[href='#{client_login_path}']", text: /Choose another event/i, count: 0
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
