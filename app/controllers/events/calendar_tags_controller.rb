module Events
  class CalendarTagsController < ApplicationController
    before_action :set_event
    before_action :set_calendar
    before_action :set_tag, only: %i[update destroy]

    def create
      @tag = @calendar.event_calendar_tags.new(tag_params)

      if @tag.save
        redirect_to event_calendar_path(@event), notice: "Tag created."
      else
        redirect_to event_calendar_path(@event), alert: @tag.errors.full_messages.to_sentence
      end
    end

    def update
      if @tag.update(tag_params)
        redirect_to event_calendar_path(@event), notice: "Tag updated."
      else
        redirect_to event_calendar_path(@event), alert: @tag.errors.full_messages.to_sentence
      end
    end

    def destroy
      @tag.destroy
      redirect_to event_calendar_path(@event), notice: "Tag removed."
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

    def set_tag
      @tag = @calendar.event_calendar_tags.find(params[:id])
    end

    def tag_params
      params.require(:event_calendar_tag).permit(:name, :color_token)
    end
  end
end
