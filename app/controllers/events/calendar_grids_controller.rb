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
                  :time_amount_unit_options,
                  :relative_timing_summary,
                  :grid_timing_summary,
                  :grid_duration_summary

    TIME_AMOUNT_UNIT_OPTIONS = Calendars::TimeAmount::UNIT_OPTIONS

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
      redirect_to safe_return_to(fallback: grid_path)
    end

    private

    def set_event
      @event = find_accessible_event!(params[:event_id])
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
      @bulk_team_members = @event.team_members.where.not(role: User::ROLES[:client]).order(:name)
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
        :duration_display_value,
        :duration_display_unit,
        :duration_display_hours,
        :duration_display_minutes,
        :status,
        :vendor_name,
        :location_name,
        :notes,
        :relative_anchor_id,
        :relative_offset_minutes,
        :relative_offset_value,
        :relative_offset_unit,
        :relative_offset_display_value,
        :relative_offset_display_unit,
        :relative_offset_display_hours,
        :relative_offset_display_minutes,
        :relative_alignment,
        :relative_before,
        :relative_to_anchor_end,
        event_calendar_tag_ids: []
      )

      assign_duration_params(permitted)
      permitted[:starts_at] = permitted[:starts_at].presence if permitted.key?(:starts_at)
      if permitted.key?(:event_calendar_tag_ids)
        tag_ids = Array(permitted.delete(:event_calendar_tag_ids)).reject(&:blank?).map(&:to_i)
        permitted[:event_calendar_tag_ids] = tag_ids
      end

      anchor_id = permitted[:relative_anchor_id].presence
      permitted[:relative_anchor_id] = anchor_id

      alignment = permitted.delete(:relative_alignment)

      if anchor_id.present?
        assign_relative_offset_params(permitted)
        apply_relative_reference_params(permitted, alignment)
      else
        permitted.delete(:relative_offset_value)
        permitted.delete(:relative_offset_unit)
        permitted[:relative_offset_minutes] = 0
        permitted[:relative_offset_display_value] = 0
        permitted[:relative_offset_display_unit] = "days"
        permitted[:relative_offset_display_hours] = 0
        permitted[:relative_offset_display_minutes] = 0
        permitted[:relative_before] = false
        permitted[:relative_to_anchor_end] = false
      end

      permitted
    end

    def bulk_params
      params.fetch(:bulk, {}).permit(
        :bulk_action,
        :status,
        :vendor_name,
        :location_name,
        :time_caption,
        :additional_team_members,
        tag_ids: [],
        team_member_ids: []
      )
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

    def time_amount_unit_options
      TIME_AMOUNT_UNIT_OPTIONS
    end

    def relative_timing_summary(item)
      return "Absolute start" unless item.relative_anchor

      amount = item.relative_offset_time_amount
      direction = item.relative_before? ? "before" : "after"
      anchor_point = item.relative_to_anchor_end? ? "ends" : "starts"
      projected_label = item.effective_starts_at&.in_time_zone(@timezone)&.then { |time| format_projected_time(time) }
      projected_suffix = projected_label.present? ? " → #{projected_label}" : ""

      if amount.total_minutes.to_i.zero?
        "Starts when #{item.relative_anchor.title} #{anchor_point}#{projected_suffix}"
      else
        "Starts #{amount.label} #{direction} #{item.relative_anchor.title} #{anchor_point}#{projected_suffix}"
      end
    end

    def grid_timing_summary(item)
      return relative_timing_summary(item) if item.relative_anchor

      start_label = item.effective_starts_at&.in_time_zone(@timezone)&.then { |time| format_projected_time(time) }
      start_label.present? ? "Starts #{start_label}" : "Start time TBD"
    end

    def grid_duration_summary(item)
      amount = item.duration_time_amount
      amount.null? ? "" : "Duration #{amount.label}"
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

    def assign_duration_params(permitted)
      return unless duration_time_amount_params_present?(permitted)

      amount = if display_time_amount_params_present?(permitted, :duration)
                 time_amount_from_display_params(permitted, :duration, nullable: true)
               else
                 Calendars::TimeAmount.from_minutes(permitted.delete(:duration_minutes).presence, nullable: true)
               end

      permitted[:duration_minutes] = amount.total_minutes
      permitted[:duration_display_value] = amount.value
      permitted[:duration_display_unit] = amount.unit
      permitted[:duration_display_hours] = amount.hours
      permitted[:duration_display_minutes] = amount.minutes
    end

    def assign_relative_offset_params(permitted)
      amount = if display_time_amount_params_present?(permitted, :relative_offset)
                 time_amount_from_display_params(permitted, :relative_offset)
               elsif legacy_relative_offset_params_present?(permitted)
                 legacy_relative_offset_amount(permitted)
               elsif permitted.key?(:relative_offset_minutes)
                 Calendars::TimeAmount.from_minutes(permitted.delete(:relative_offset_minutes), preferred_unit: "days")
               else
                 @item.relative_offset_time_amount
               end

      permitted[:relative_offset_minutes] = amount.total_minutes
      permitted[:relative_offset_display_value] = amount.value
      permitted[:relative_offset_display_unit] = amount.unit
      permitted[:relative_offset_display_hours] = amount.hours
      permitted[:relative_offset_display_minutes] = amount.minutes
      permitted.delete(:relative_offset_value)
      permitted.delete(:relative_offset_unit)
    end

    def duration_time_amount_params_present?(permitted)
      permitted.key?(:duration_minutes) || display_time_amount_params_present?(permitted, :duration)
    end

    def display_time_amount_params_present?(permitted, prefix)
      permitted.key?(:"#{prefix}_display_value") ||
        permitted.key?(:"#{prefix}_display_unit") ||
        permitted.key?(:"#{prefix}_display_hours") ||
        permitted.key?(:"#{prefix}_display_minutes")
    end

    def time_amount_from_display_params(permitted, prefix, nullable: false)
      Calendars::TimeAmount.from_display(
        value: permitted.delete(:"#{prefix}_display_value"),
        unit: permitted.delete(:"#{prefix}_display_unit"),
        hours: permitted.delete(:"#{prefix}_display_hours"),
        minutes: permitted.delete(:"#{prefix}_display_minutes"),
        nullable:
      )
    end

    def legacy_relative_offset_params_present?(permitted)
      permitted.key?(:relative_offset_value) || permitted.key?(:relative_offset_unit)
    end

    def legacy_relative_offset_amount(permitted)
      raw_value = permitted.delete(:relative_offset_value).to_s.strip
      unit = permitted.delete(:relative_offset_unit).to_s.strip
      return Calendars::TimeAmount.from_minutes(0, preferred_unit: "days") if raw_value.blank?

      multiplier = case unit
                   when "hours" then 60
                   when "days" then 60 * 24
                   when "weeks" then 60 * 24 * 7
                   when "months" then 60 * 24 * 30
                   else 1
                   end
      preferred_unit = unit.in?(Calendars::TimeAmount::MAJOR_UNITS.keys) ? unit : "days"

      Calendars::TimeAmount.from_minutes((raw_value.to_f * multiplier).to_i, preferred_unit:)
    end

    def format_anchor_time(time)
      time.strftime("%b %-d %-l:%M %p")
    end

    def format_projected_time(time)
      time.strftime("%b %-d %-l:%M%p").sub(/^Sep /, "Sept ")
    end
  end
end
