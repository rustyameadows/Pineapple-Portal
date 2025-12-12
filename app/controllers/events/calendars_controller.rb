module Events
  class CalendarsController < ApplicationController
    helper CalendarHelper

    before_action :set_event
    before_action :ensure_calendar, only: %i[show update timeline_preview]
    before_action :load_collections, only: %i[show update]

    def index
      @calendar = @event.run_of_show_calendar || build_default_calendar
      @views = @calendar.event_calendar_views.order(:position)
      @tag_lookup = @calendar.event_calendar_tags.index_by(&:id)
      @tags = @calendar.event_calendar_tags.order(Arel.sql("LOWER(name) ASC"))
      @new_tag = EventCalendarTag.new(event_calendar: @calendar)
      @time_zones = ActiveSupport::TimeZone.all
    end

    def show; end

    def timeline_preview
      @items = @calendar.calendar_items
                         .includes(:event_calendar_tags, :team_members, :relative_anchor)
                         .ordered
      @segment = Struct.new(:title, :html_options, :html_view_key).new(
        title: @calendar.name,
        html_options: {},
        html_view_key: DocumentSegment::RUN_OF_SHOW_VIEW_KEY
      )
      render template: "generated_documents/sections/timeline", layout: "generated_preview"
    end

    def update
      if @calendar.update(calendar_params)
        redirect_to event_calendar_path(@event), notice: "Calendar details updated."
      else
        flash.now[:alert] = @calendar.errors.full_messages.to_sentence
        render :show, status: :unprocessable_content
      end
    end

    private

    def set_event
      @event = Event.find(params[:event_id])
    end

    def ensure_calendar
      @calendar = @event.run_of_show_calendar
      @calendar ||= build_default_calendar
    end

    def load_collections
      @items = @calendar.calendar_items
                         .includes(:relative_anchor, :event_calendar_tags)
                         .ordered
                         .reject { |item| item.tagged_with?("decisions") }
      @tags = @calendar.event_calendar_tags.order(:position)
      @tags_by_id = @tags.index_by(&:id)
      @views = @calendar.event_calendar_views.order(:position)
      @new_tag = EventCalendarTag.new(event_calendar: @calendar)
      @time_zones = ActiveSupport::TimeZone.all
      @group_by_date = true
    end

    def calendar_params
      params.require(:event_calendar).permit(:name, :description, :timezone, :client_visible)
    end

    def build_default_calendar
      @event.event_calendars.create!(
        name: "Run of Show",
        timezone: EventCalendar::DEFAULT_TIMEZONE
      )
    end
  end
end
