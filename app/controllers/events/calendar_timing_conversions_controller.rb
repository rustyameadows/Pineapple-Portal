module Events
  class CalendarTimingConversionsController < ApplicationController
    before_action :set_event
    before_action :set_calendar

    def create
      result = run_conversion
      flash_key = result.success? ? :notice : :alert

      redirect_to safe_return_to(fallback: event_calendar_path(@event)),
                  flash: { flash_key => result.message }
    end

    private

    def set_event
      @event = find_accessible_event!(params[:event_id])
    end

    def set_calendar
      @calendar = @event.run_of_show_calendar || @event.event_calendars.create!(
        name: "Run of Show",
        timezone: EventCalendar::DEFAULT_TIMEZONE
      )
    end

    def run_conversion
      case timing_conversion_params[:mode].to_s
      when "absolute"
        Calendars::Commands::ConvertToAbsolute.new(calendar: @calendar).call(
          item_id: timing_conversion_params[:target_item_id]
        )
      when "relative"
        Calendars::Commands::ConvertToRelative.new(calendar: @calendar).call(
          target_item_id: timing_conversion_params[:target_item_id],
          anchor_item_id: timing_conversion_params[:anchor_item_id],
          anchor_point: timing_conversion_params[:anchor_point]
        )
      else
        unknown_mode_result
      end
    end

    def timing_conversion_params
      @timing_conversion_params ||= params.fetch(:timing_conversion, {}).permit(
        :mode,
        :target_item_id,
        :anchor_item_id,
        :anchor_point
      )
    end

    def unknown_mode_result
      Struct.new(:success, :message, keyword_init: true) do
        def success?
          success
        end
      end.new(success: false, message: "Choose a timing change.")
    end
  end
end
