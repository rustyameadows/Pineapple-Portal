module Events
  class CalendarGridsController < ApplicationController
    helper CalendarHelper

    before_action :set_event
    before_action :set_calendar
    before_action :set_view, if: -> { params[:id].present? }
    helper_method :grid_path,
                  :grid_item_path,
                  :grid_bulk_path,
                  :return_path,
                  :calendar_timezone_label,
                  :anchor_options_for,
                  :relative_offset_value,
                  :relative_offset_unit,
                  :relative_timing_summary

    OFFSET_UNITS = [
      ["Minutes", "minutes"],
      ["Hours", "hours"],
      ["Days", "days"],
      ["Weeks", "weeks"],
      ["Months", "months"]
    ].freeze

    def show
      load_grid
    end

    def update
      @item = @calendar.calendar_items.find(item_id_param)
      if @item.update(grid_item_params)
        Calendars::CascadeScheduler.new(@calendar).call
        redirect_to grid_path, notice: "Calendar item updated."
      else
        load_grid
        replace_item_in_collection(@item)
        flash.now[:alert] = @item.errors.full_messages.to_sentence
        render :show, status: :unprocessable_content
      end
    end

    def bulk_update
      ids = Array(params[:item_ids]).map(&:to_i).reject(&:zero?)
      result = Calendars::GridBulkUpdater.new(
        calendar: @calendar,
        item_ids: ids,
        params: bulk_params
      ).call

      flash[result.success? ? :notice : :alert] = result.message
      redirect_to grid_path
    end

    private

    def set_event
      @event = Event.find(params[:event_id])
    end

    def set_calendar
      @calendar = @event.run_of_show_calendar
      @calendar ||= @event.event_calendars.create!(
        name: "Run of Show",
        timezone: EventCalendar::DEFAULT_TIMEZONE
      )
    end

    def set_view
      @view = @calendar.event_calendar_views.find(params[:id])
    end

    def load_grid
      @items = if @view
                 Calendars::ViewFilter.new(calendar: @calendar, view: @view).items
               else
                 @calendar.calendar_items.includes(:event_calendar_tags, :relative_anchor).ordered
               end
      @tags = @calendar.event_calendar_tags.order(:position, :name)
      @statuses = CalendarItem.statuses.keys
      @timezone = ActiveSupport::TimeZone[@calendar.timezone] || ActiveSupport::TimeZone[EventCalendar::DEFAULT_TIMEZONE]
      @anchor_options = build_anchor_options
    end

    def replace_item_in_collection(updated_item)
      @items = Array(@items).map do |item|
        item.id == updated_item.id ? updated_item : item
      end
    end

    def grid_item_params
      permitted = params.require(:calendar_item).permit(
        :title,
        :starts_at,
        :duration_minutes,
        :status,
        :locked,
        :vendor_name,
        :location_name,
        :notes,
        :relative_anchor_id,
        :relative_offset_minutes,
        :relative_offset_value,
        :relative_offset_unit,
        :relative_alignment,
        :relative_before,
        :relative_to_anchor_end,
        event_calendar_tag_ids: []
      )

      permitted[:duration_minutes] = permitted[:duration_minutes].presence if permitted.key?(:duration_minutes)
      permitted[:starts_at] = permitted[:starts_at].presence if permitted.key?(:starts_at)
      permitted[:locked] = ActiveModel::Type::Boolean.new.cast(permitted[:locked]) if permitted.key?(:locked)
      if permitted.key?(:event_calendar_tag_ids)
        tag_ids = Array(permitted.delete(:event_calendar_tag_ids)).reject(&:blank?).map(&:to_i)
        permitted[:event_calendar_tag_ids] = tag_ids
      end

      anchor_id = permitted[:relative_anchor_id].presence
      permitted[:relative_anchor_id] = anchor_id

      alignment = permitted.delete(:relative_alignment)
      offset_value = permitted.delete(:relative_offset_value)
      offset_unit = permitted.delete(:relative_offset_unit)

      if anchor_id.present?
        permitted[:relative_offset_minutes] = relative_offset_minutes_from(offset_value, offset_unit, permitted[:relative_offset_minutes])
        apply_relative_reference_params(permitted, alignment)
      else
        permitted[:relative_offset_minutes] = 0
        permitted[:relative_before] = false
        permitted[:relative_to_anchor_end] = false
      end

      permitted
    end

    def bulk_params
      params.fetch(:bulk, {}).permit(:bulk_action, :status, :locked, tag_ids: [])
    end

    def grid_path
      if @view
        grid_event_calendar_view_path(@event, @view)
      else
        grid_event_calendar_path(@event)
      end
    end

    def grid_item_path(item)
      if @view
        grid_item_event_calendar_view_path(@event, @view, item)
      else
        grid_item_event_calendar_path(@event, item)
      end
    end

    def grid_bulk_path
      if @view
        grid_bulk_event_calendar_view_path(@event, @view)
      else
        grid_bulk_event_calendar_path(@event)
      end
    end

    def return_path
      if @view
        event_calendar_view_path(@event, @view)
      else
        event_calendar_path(@event)
      end
    end

    def calendar_timezone_label
      @timezone ? @timezone.to_s : @calendar.timezone
    end

    def item_id_param
      params[:item_id] || params[:id]
    end

    def build_anchor_options
      @calendar.calendar_items.order(:starts_at, :position, :id).map do |item|
        [anchor_option_label(item), item.id, anchor_option_attributes(item)]
      end
    end

    def anchor_option_label(item)
      start_time = item.effective_starts_at&.in_time_zone(@timezone)
      end_time = item.effective_ends_at&.in_time_zone(@timezone)
      time_label = if start_time && end_time
                     "#{format_anchor_time(start_time)} – #{end_time.strftime('%-l:%M %p')}"
                   elsif start_time
                     format_anchor_time(start_time)
                   else
                     "TBD"
                   end
      "#{item.title} (#{time_label})"
    end

    def anchor_option_attributes(item)
      {
        data: {
          anchor_title: item.title,
          anchor_start_at: item.effective_starts_at&.iso8601,
          anchor_end_at: item.effective_ends_at&.iso8601
        }.compact
      }
    end

    def anchor_options_for(item)
      [["None (absolute)", ""]] + @anchor_options.reject { |(_label, id, _attributes)| id == item.id }
    end

    def relative_offset_value(item)
      relative_offset_parts(item).first
    end

    def relative_offset_unit(item)
      relative_offset_parts(item).last
    end

    def relative_timing_summary(item)
      return "Absolute start" unless item.relative_anchor

      value, unit = relative_offset_parts(item)
      direction = item.relative_before? ? "before" : "after"
      anchor_point = item.relative_to_anchor_end? ? "ends" : "starts"
      projected_label = item.effective_starts_at&.in_time_zone(@timezone)&.then { |time| format_projected_time(time) }
      projected_suffix = projected_label.present? ? " → #{projected_label}" : ""

      if value.to_f.zero?
        "Starts when #{item.relative_anchor.title} #{anchor_point}#{projected_suffix}"
      else
        "Starts #{value} #{unit_label(value, unit)} #{direction} #{item.relative_anchor.title} #{anchor_point}#{projected_suffix}"
      end
    end

    def relative_offset_parts(item)
      minutes = item.relative_offset_minutes.to_i.abs
      return [0, "minutes"] if minutes.zero?

      if (minutes % (60 * 24 * 30)).zero?
        [minutes / (60 * 24 * 30), "months"]
      elsif (minutes % (60 * 24 * 7)).zero?
        [minutes / (60 * 24 * 7), "weeks"]
      elsif (minutes % (60 * 24)).zero?
        [minutes / (60 * 24), "days"]
      elsif minutes >= 60 && (minutes % 15).zero?
        [trim_decimal(minutes / 60.0), "hours"]
      else
        [minutes, "minutes"]
      end
    end

    def apply_relative_reference_params(permitted, alignment)
      if permitted.key?(:relative_before) || permitted.key?(:relative_to_anchor_end)
        permitted[:relative_before] = ActiveModel::Type::Boolean.new.cast(permitted[:relative_before])
        permitted[:relative_to_anchor_end] = ActiveModel::Type::Boolean.new.cast(permitted[:relative_to_anchor_end])
        return
      end

      case alignment
      when "before_start"
        permitted[:relative_before] = true
        permitted[:relative_to_anchor_end] = false
      when "after_end"
        permitted[:relative_before] = false
        permitted[:relative_to_anchor_end] = true
      when "before_end"
        permitted[:relative_before] = true
        permitted[:relative_to_anchor_end] = true
      else # default to after_start
        permitted[:relative_before] = false
        permitted[:relative_to_anchor_end] = false
      end
    end

    def relative_offset_minutes_from(value, unit, fallback_minutes)
      raw_value = value.to_s.strip
      return fallback_minutes.to_i if raw_value.blank? && fallback_minutes.present?
      return 0 if raw_value.blank?

      multiplier = case unit.to_s
                   when "hours" then 60
                   when "days" then 60 * 24
                   when "weeks" then 60 * 24 * 7
                   when "months" then 60 * 24 * 30
                   else 1
                   end

      (raw_value.to_f * multiplier).to_i
    end

    def unit_label(value, unit)
      value.to_f == 1.0 ? unit.singularize : unit
    end

    def trim_decimal(value)
      return value.to_i if value == value.to_i

      value.round(2).to_s.sub(/\.?0+\z/, "")
    end

    def format_anchor_time(time)
      time.strftime("%b %-d %-l:%M %p")
    end

    def format_projected_time(time)
      time.strftime("%b %-d %-l:%M%p").sub(/^Sep /, "Sept ")
    end
  end
end
