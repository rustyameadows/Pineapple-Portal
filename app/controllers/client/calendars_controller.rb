module Client
  class CalendarsController < PortalController
    helper CalendarHelper
    before_action :load_calendar
    before_action :load_views
    before_action :ensure_accessible_calendar

    def index
      return if performed?

      slug = default_view_slug

      if slug
        redirect_to client_event_calendar_path(@event, slug)
      else
        redirect_to client_event_path(@event), alert: "Your planning team hasn’t published calendars yet."
      end
    end

    def show
      return if performed?

      @active_view = locate_view

      unless @active_view
        redirect_to client_event_path(@event), alert: "Your planning team hasn’t published calendars yet."
        return
      end

      if decision_calendar_view?(@active_view)
        build_decision_calendar_payload
        render :decision
      else
        @timezone_label = display_timezone
        @filter = ::Calendars::ViewFilter.new(calendar: @calendar, view: @active_view)
        @items = @filter.items
      end
    end

    private

    def load_calendar
      @calendar = @event.run_of_show_calendar
      return if @calendar

      redirect_to client_event_path(@event), alert: "Your planning team hasn’t published the schedule yet."
    end

    def load_views
      return unless @calendar

      @views = @calendar.event_calendar_views.client_visible.order(:position)
    end

    def ensure_accessible_calendar
      return if performed?

      return if accessible_run_of_show? || @views.any?

      redirect_to client_event_path(@event), alert: "Your planning team hasn’t published calendars yet."
    end

    def default_view_slug
      return "run-of-show" if accessible_run_of_show?

      @views.first&.slug
    end

    def locate_view
      slug = params[:slug]

      if run_of_show_slug?(slug)
        return Client::Calendars::SelectedView.run_of_show(@calendar) if accessible_run_of_show?
      else
        matching_view = @views.find { |view| view.slug == slug }
        return wrap_view(matching_view) if matching_view
      end

      return Client::Calendars::SelectedView.run_of_show(@calendar) if accessible_run_of_show?
      wrap_view(@views.first)
    end

    def run_of_show_slug?(slug)
      slug.blank? || slug == "run-of-show"
    end

    def accessible_run_of_show?
      @calendar&.client_visible?
    end

    def wrap_view(view)
      return unless view

      Client::Calendars::SelectedView.new(calendar: @calendar, view:)
    end

    def display_timezone
      zone = ActiveSupport::TimeZone[@calendar.timezone]
      zone ? zone.to_s : @calendar.timezone
    end

    def decision_calendar_view?(selected_view)
      selected_view.slug == "decision-calendar"
    end

    def build_decision_calendar_payload
      @decision_title = @active_view.name.presence || "Decision Calendar"
      @decision_description = @active_view.description
      @decision_items = decision_calendar_segments
    end

    def decision_calendar_segments
      raw_items = ::Calendars::ViewFilter.new(calendar: @calendar, view: @active_view).items
      grouped = raw_items.group_by { |item| segment_label_for(item) }

      grouped.map do |segment, items|
        {
          label: segment,
          items: items.sort_by { |it| it.title.to_s.downcase },
          sort_key: items.map { |it| it.effective_starts_at || it.created_at }.compact.min
        }
      end
        .sort_by { |segment| [segment[:sort_key] || Time.zone.at(0), segment[:label]] }
        .map { |segment| segment.except(:sort_key) }
    end

    def segment_label_for(item)
      start_time = item.effective_starts_at&.in_time_zone(@calendar.timezone)
      return "Upcoming Decisions" unless start_time

      start_time.strftime("%A, %B %-d")
    end
  end
end
