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
                  :anchor_alignment_options,
                  :anchor_alignment_value

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
      @anchor_label_map = @anchor_options.to_h { |label, id| [id, label] }
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
        :relative_alignment,
        event_calendar_tag_ids: []
      )

      permitted[:duration_minutes] = permitted[:duration_minutes].presence
      permitted[:starts_at] = permitted[:starts_at].presence
      permitted[:locked] = ActiveModel::Type::Boolean.new.cast(permitted[:locked])
      tag_ids = Array(permitted.delete(:event_calendar_tag_ids)).reject(&:blank?).map(&:to_i)
      permitted[:event_calendar_tag_ids] = tag_ids

      anchor_id = permitted[:relative_anchor_id].presence
      permitted[:relative_anchor_id] = anchor_id

      alignment = permitted.delete(:relative_alignment)

      if anchor_id.present?
        permitted[:relative_offset_minutes] = permitted[:relative_offset_minutes].presence || 0
        permitted[:relative_offset_minutes] = permitted[:relative_offset_minutes].to_i

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
        [anchor_option_label(item), item.id]
      end
    end

    def anchor_option_label(item)
      time = item.starts_at&.in_time_zone(@timezone)
      time_label = time ? time.strftime("%b %-d %H:%M") : "TBD"
      "#{item.title} (#{time_label})"
    end

    def anchor_options_for(item)
      [["None (absolute)", ""]] + @anchor_options.reject { |(_, id)| id == item.id }
    end

    def anchor_alignment_options(_item = nil)
      [
        ["After anchor start", "after_start"],
        ["Before anchor start", "before_start"],
        ["After anchor end", "after_end"],
        ["Before anchor end", "before_end"]
      ]
    end

    def anchor_alignment_value(item)
      return "after_start" unless item.relative_anchor_id.present?

      if item.relative_before? && item.relative_to_anchor_end?
        "before_end"
      elsif item.relative_before?
        "before_start"
      elsif item.relative_to_anchor_end?
        "after_end"
      else
        "after_start"
      end
    end
  end
end
