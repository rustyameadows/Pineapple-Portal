module ClientPortal
  module PlanningLinks
    Link = Struct.new(:key, :title, :description, :path, :default_visible, keyword_init: true)

    ROUTES = Rails.application.routes.url_helpers
    DECISION_CALENDAR_SLUG = "decision-calendar".freeze

    module_function

    def built_in_links_for(event)
      context = build_context(event)

      built_in_definitions.filter_map do |definition|
        attributes = definition[:resolver].call(event, context)
        next unless attributes

        Link.new(**attributes.merge(default_visible: definition.fetch(:default_visible, true)))
      end
    end

    def built_in_keys
      built_in_definitions.map { |definition| definition[:key] }
    end

    def default_keys
      built_in_definitions
        .select { |definition| definition.fetch(:default_visible, true) }
        .map { |definition| definition[:key] }
    end

    def build_context(event)
      calendar = event.run_of_show_calendar
      visible_views = calendar&.event_calendar_views&.client_visible&.order(:position) || EventCalendarView.none
      decision_view = visible_views.find { |view| view.slug == DECISION_CALENDAR_SLUG }

      {
        calendar: calendar,
        visible_views: visible_views,
        decision_view: decision_view
      }
    end

    def built_in_definitions
      @built_in_definitions ||= [
        {
          key: "decision_calendar",
          default_visible: true,
          resolver: lambda do |event, context|
            decision_view = context[:decision_view]
            calendar = context[:calendar]
            return unless decision_view && calendar

            {
              key: "decision_calendar",
              title: "Decision Calendar",
              description: "Milestones and approvals at a glance.",
              path: ROUTES.client_event_calendar_path(event.portal_slug.presence || event.id, decision_view.slug)
            }
          end
        },
        {
          key: "guest_list",
          default_visible: true,
          resolver: lambda do |event, _context|
            {
              key: "guest_list",
              title: "Guest List",
              description: "Track RSVPs and key contacts.",
              path: ROUTES.client_event_guest_list_path(event.portal_slug.presence || event.id)
            }
          end
        },
        {
          key: "questionnaires",
          default_visible: true,
          resolver: lambda do |event, _context|
            {
              key: "questionnaires",
              title: "Questionnaires",
              description: "Complete and review planner questionnaires.",
              path: ROUTES.client_event_questionnaires_path(event.portal_slug.presence || event.id)
            }
          end
        },
        {
          key: "designs",
          default_visible: true,
          resolver: lambda do |event, _context|
            {
              key: "designs",
              title: "Design & Inspo",
              description: "Mood boards, files, and inspiration assets.",
              path: ROUTES.client_event_designs_path(event.portal_slug.presence || event.id)
            }
          end
        },
        {
          key: "financials",
          default_visible: true,
          resolver: lambda do |event, _context|
            {
              key: "financials",
              title: "Financial Management",
              description: "Invoices, payments, and budget progress.",
              path: ROUTES.client_event_financials_path(event.portal_slug.presence || event.id)
            }
          end
        }
      ].freeze
    end
  end
end
