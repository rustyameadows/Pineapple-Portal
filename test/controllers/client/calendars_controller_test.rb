require "test_helper"

module Client
  class CalendarsControllerTest < ActionDispatch::IntegrationTest
    setup do
      @event = events(:one)
      @calendar = event_calendars(:run_of_show)
      @view = event_calendar_views(:vendor_view)
      log_in_client_portal(users(:client_contact))
    end

    test "index redirects to run of show when visible" do
      get client_event_calendars_path(@event.portal_slug)

      assert_redirected_to client_event_calendar_path(@event.portal_slug, "run-of-show")
    end

    test "index redirects to first visible derived view when run of show hidden" do
      @calendar.update!(client_visible: false)

      get client_event_calendars_path(@event.portal_slug)

      assert_redirected_to client_event_calendar_path(@event.portal_slug, @view.slug)
    end

    test "show renders schedule" do
      get client_event_calendar_path(@event.portal_slug, "run-of-show")

      assert_response :success
      assert_includes response.body, "Ceremony"
      assert_includes response.body, "Run of Show"
    end

    test "decision calendar renders segmented list" do
      get client_event_calendar_path(@event.portal_slug, "decision-calendar")

      assert_response :success
      assert_select "section.decision-calendar h1", text: "Decision Calendar"
      assert_select ".decision-calendar__row", minimum: 1
      assert_select ".decision-calendar__actions .client-button", text: "Back to Portal"
    end

    test "show redirects when nothing published" do
      @calendar.update!(client_visible: false)
      @view.update!(client_visible: false)
      event_calendar_views(:decision_view).update!(client_visible: false)

      get client_event_calendar_path(@event.portal_slug, "run-of-show")

      assert_redirected_to client_event_path(@event.portal_slug)
      assert_equal "Your planning team hasn’t published calendars yet.", flash[:alert]
    end
  end
end
