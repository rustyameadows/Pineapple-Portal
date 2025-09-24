module Events
  class CalendarViewsController < ApplicationController
    helper CalendarHelper

    before_action :set_event
    before_action :set_calendar
    before_action :set_view, only: %i[show edit update destroy]
    before_action :load_tags, only: %i[new edit show]

    def show
      @filter = Calendars::ViewFilter.new(calendar: @calendar, view: @view)
      @items = @filter.items
    end

    def new
      @view = @calendar.event_calendar_views.new
    end

    def create
      @view = @calendar.event_calendar_views.new(view_params)

      if @view.save
        redirect_to event_calendars_path(@event), notice: "Derived calendar created."
      else
        load_tags
        flash.now[:alert] = @view.errors.full_messages.to_sentence
        render :new, status: :unprocessable_content
      end
    end

    def edit; end

    def update
      if @view.update(view_params)
        redirect_to event_calendar_view_path(@event, @view), notice: "Derived calendar updated."
      else
        load_tags
        flash.now[:alert] = @view.errors.full_messages.to_sentence
        render :edit, status: :unprocessable_content
      end
    end

    def destroy
      @view.destroy
      redirect_to event_calendars_path(@event), notice: "Derived calendar removed."
    end

    private

    def set_event
      @event = Event.find(params[:event_id])
    end

    def set_calendar
      @calendar = @event.run_of_show_calendar || @event.event_calendars.create!(
        name: "Run of Show",
        timezone: EventCalendar::DEFAULT_TIMEZONE
      )
    end

    def set_view
      @view = @calendar.event_calendar_views.find(params[:id])
    end

    def load_tags
      @tags = @calendar.event_calendar_tags.order(:position)
      @tags_by_id = @tags.index_by(&:id)
    end

    def view_params
      params.require(:event_calendar_view).permit(
        :name,
        :slug,
        :description,
        :hide_locked,
        :client_visible,
        tag_filter: []
      )
    end
  end
end
