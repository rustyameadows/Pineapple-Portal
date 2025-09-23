module Events
  class CalendarsController < ApplicationController
    before_action :set_event
    before_action :ensure_calendar
    before_action :load_collections, only: %i[show update]

    def show; end

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
      return if @calendar

      @calendar = @event.event_calendars.create!(
        name: "Run of Show",
        timezone: Time.zone.tzinfo&.identifier || Time.zone.name || "UTC"
      )
    end

    def load_collections
      @items = @calendar.calendar_items.includes(:relative_anchor, :event_calendar_tags).ordered
      @tags = @calendar.event_calendar_tags.order(:position)
      @tags_by_id = @tags.index_by(&:id)
      @views = @calendar.event_calendar_views.order(:position)
      @new_tag = @calendar.event_calendar_tags.new
      @time_zones = ActiveSupport::TimeZone.all
    end

    def calendar_params
      params.require(:event_calendar).permit(:name, :description, :timezone, :client_visible)
    end
  end
end
