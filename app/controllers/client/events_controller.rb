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
      calendar = @event.run_of_show_calendar
      links = @event.event_links.ordered.to_a

      return links unless calendar

      calendar_links = []

      if calendar.client_visible?
        calendar_links << QuickLink.new("Run of Show", client_event_calendar_path(@event, "run-of-show"))
      end

      calendar.event_calendar_views.client_visible.order(:position).each do |view|
        calendar_links << QuickLink.new(view.name, client_event_calendar_path(@event, view.slug))
      end

      links + calendar_links
    end

    def build_module_cards
      calendar = @event.run_of_show_calendar
      visible_views = calendar&.event_calendar_views&.client_visible&.order(:position) || EventCalendarView.none

      cards = []

      if calendar&.client_visible? || visible_views.any?
        default_slug = calendar&.client_visible? ? "run-of-show" : visible_views.first.slug
        cards << {
          title: "Event Schedule",
          description: "See the master run of show and shared timelines.",
          path: client_event_calendar_path(@event, default_slug)
        }
      end

      cards.concat(
        [
          {
            title: "Decision Calendar",
            description: "Milestones and approvals at a glance.",
            path: client_event_decision_calendar_path(@event)
          },
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
        ]
      )
    end
  end
end
