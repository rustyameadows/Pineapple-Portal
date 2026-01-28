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
      slug = params[:event_slug].presence || params[:slug]
      @event = if slug.present?
                 Event.find_by!(portal_slug: slug)
               else
                 Event.find(params[:id])
               end
    end

    def build_quick_links
      @event.event_links.quick.ordered.to_a
    end

    def build_module_cards
      entries = @event.ordered_planning_link_entries
      event_key = @event.portal_slug.presence || @event.id

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
          url = link.url.to_s
          {
            key: "event_link_#{link.id}",
            title: link.label,
            path: url.start_with?("/") ? "/client/#{event_key}#{url}" : url,
            external: !url.start_with?("/")
          }
        end
      end
    end
  end
end
