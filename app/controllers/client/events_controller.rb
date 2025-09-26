module Client
  class EventsController < BaseController
    QuickLink = Struct.new(:label, :url)

    before_action :set_event

    def show
      @quick_links = build_quick_links
      @module_cards = build_module_cards
      @planning_team_members = @event.event_team_members.includes(:user).client_visible.references(:users).order("users.name")
    end

    private

    def set_event
      @event = Event.find(params[:id])
    end

    def build_quick_links
      @event.event_links.ordered.to_a
    end

    def build_module_cards
      calendar = @event.run_of_show_calendar
      visible_views = calendar&.event_calendar_views&.client_visible&.order(:position) || EventCalendarView.none

      cards = []

      decision_view = visible_views.find { |view| view.slug == "decision-calendar" }

      cards.concat(
        [
          (decision_view && calendar ?
            {
              title: "Decision Calendar",
              description: "Milestones and approvals at a glance.",
              path: client_event_calendar_path(@event, decision_view.slug)
            } : nil),
          {
            title: "Guest List",
            description: "Track RSVPs and key contacts.",
            path: client_event_guest_list_path(@event)
          },
          {
            title: "Questionnaires",
            description: "Complete and review planner questionnaires.",
            path: client_event_questionnaires_path(@event)
          },
          {
            title: "Design & Inspo",
            description: "Mood boards, files, and inspiration assets.",
            path: client_event_designs_path(@event)
          },
          {
            title: "Financial Management",
            description: "Invoices, payments, and budget progress.",
            path: client_event_financials_path(@event)
          }
        ].compact
      )
    end
  end
end
