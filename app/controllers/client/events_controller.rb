module Client
  class EventsController < BaseController
    QuickLink = Struct.new(:label, :url)

    before_action :set_event

    def show
      @quick_links = build_quick_links
      @module_cards = build_module_cards
      @planning_team_members = @event.planner_team_members
                                      .includes(:user)
                                      .client_visible
                                      .left_joins(:user)
                                      .ordered_for_display
                                      .order("users.name")
    end

    private

    def set_event
      @event = Event.find(params[:id])
    end

    def build_quick_links
      @event.event_links.quick.ordered.to_a
    end

    def build_module_cards
      entries = @event.ordered_planning_link_entries

      unless financial_portal_access?
        entries = entries.reject do |entry|
          (entry.kind == :built_in && entry.record&.key == "financials") ||
            (entry.kind == :event_link && entry.record.respond_to?(:financial_only) && entry.record.financial_only?)
        end
      end

      entries.map do |entry|
        case entry.kind
        when :built_in
          link = entry.record
          {
            key: link.key,
            title: link.title,
            path: link.path,
            external: false
          }
        else
          link = entry.record
          {
            key: "event_link_#{link.id}",
            title: link.label,
            path: link.url,
            external: true
          }
        end
      end
    end
  end
end
