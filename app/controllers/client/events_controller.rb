module Client
  class EventsController < BaseController
    before_action :set_event

    def show
      @quick_links = @event.event_links.ordered
      @module_cards = [
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
    end

    private

    def set_event
      @event = Event.find(params[:id])
    end
  end
end
