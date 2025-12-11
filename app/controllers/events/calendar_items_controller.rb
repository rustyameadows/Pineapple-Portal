module Events
  class CalendarItemsController < ApplicationController
    helper CalendarHelper

    before_action :set_event
    before_action :set_calendar
    before_action :set_item, only: %i[edit update destroy mark_completed mark_planned remove_milestone_tag]
    before_action :load_form_support, only: %i[new edit create update]
    before_action :load_dependents, only: %i[edit]

    def new
      @item = @calendar.calendar_items.new
      if params[:milestone] == "1"
        milestone_tag = ensure_milestone_tag
        @item.event_calendar_tag_ids = [milestone_tag.id] if milestone_tag
      end
    end

    def create
      @item = @calendar.calendar_items.new
      assign_tags(@item)
      assign_team_members(@item)
      assign_duration(@item)
      assign_offset(@item)
      apply_timing_mode(@item)
      @item.assign_attributes(item_params)

      if @item.save
        run_scheduler
        redirect_to event_calendar_path(@event), notice: "Calendar item added."
      else
        load_form_support
        flash.now[:alert] = @item.errors.full_messages.to_sentence
        render :new, status: :unprocessable_content
      end
    end

    def edit; end

    def update
      assign_tags(@item)
      assign_team_members(@item)
      assign_duration(@item)
      assign_offset(@item)
      apply_timing_mode(@item)

      if @item.update(item_params)
        run_scheduler
        redirect_to event_calendar_path(@event), notice: "Calendar item updated."
      else
        flash.now[:alert] = @item.errors.full_messages.to_sentence
        render :edit, status: :unprocessable_content
      end
    end

    def destroy
      @item.destroy
      run_scheduler
      redirect_to event_calendar_path(@event), notice: "Calendar item removed."
    end

    def mark_completed
      if @item.update(status: :completed)
        redirect_back fallback_location: event_settings_path(@event), notice: "Milestone marked as completed."
      else
        redirect_back fallback_location: event_settings_path(@event), alert: @item.errors.full_messages.to_sentence
      end
    end

    def mark_planned
      if @item.update(status: :planned)
        redirect_back fallback_location: event_settings_path(@event), notice: "Milestone reopened."
      else
        redirect_back fallback_location: event_settings_path(@event), alert: @item.errors.full_messages.to_sentence
      end
    end

    def remove_milestone_tag
      milestone_tag = ensure_milestone_tag(create: false)
      if milestone_tag
        @item.calendar_item_tags.where(event_calendar_tag: milestone_tag).destroy_all
        redirect_back fallback_location: event_settings_path(@event), notice: "Milestone tag removed."
      else
        redirect_back fallback_location: event_settings_path(@event), alert: "Milestone tag not found."
      end
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

    def set_item
      @item = @calendar.calendar_items.find(params[:id])
    end

    def load_form_support
      @available_tags = @calendar.event_calendar_tags.order(:position, :name)
      @available_team_members = @event.team_members.order(:name)
      @anchor_options = (
        @calendar.calendar_items.order(:title).map do |item|
          next if @item && item.id == @item.id

          [anchor_label(item), item.id]
        end
      ).compact
      @default_start_time = default_calendar_start_time
    end

    def anchor_label(item)
      start = item.effective_starts_at&.in_time_zone(@calendar.timezone)
      finish = item.effective_ends_at&.in_time_zone(@calendar.timezone)
      time_label = if start && finish
                     "#{start.strftime('%b %-d %l:%M %p')} – #{finish.strftime('%l:%M %p').strip}"
                   elsif start
                     start.strftime("%b %-d %l:%M %p")
                   else
                     "TBD"
                   end
      "#{item.title} (#{time_label})"
    end

    def item_params
      params.require(:calendar_item).permit(
        :title,
        :notes,
        :starts_at,
        :relative_anchor_id,
        :relative_offset_minutes,
        :relative_before,
        :locked,
        :relative_to_anchor_end,
        :vendor_name,
        :location_name,
        :status,
        :additional_team_members,
        :time_caption,
        team_member_ids: []
      )
    end

    def assign_tags(item)
      tag_ids = Array(params.dig(:calendar_item, :event_calendar_tag_ids)).reject(&:blank?).map(&:to_i)
      item.event_calendar_tag_ids = tag_ids
    end

    def assign_team_members(item)
      member_ids = Array(params.dig(:calendar_item, :team_member_ids)).reject(&:blank?).map(&:to_i)
      item.team_member_ids = member_ids
    end

    def assign_duration(item)
      raw_value = params.dig(:calendar_item, :duration_value).to_s.strip
      unit = params.dig(:calendar_item, :duration_unit).to_s.strip.presence || "minutes"

      if raw_value.blank?
        item.duration_minutes = nil
        return
      end

      value = raw_value.to_f

      multiplier = case unit
                   when "minutes" then 1
                   when "hours" then 60
                   when "days" then 60 * 24
                   when "weeks" then 60 * 24 * 7
                   when "months" then 60 * 24 * 30
                   else 1
                   end

      item.duration_minutes = (value * multiplier).to_i
    end

    def assign_offset(item)
      raw_value = params.dig(:calendar_item, :relative_offset_value).to_s.strip
      unit = params.dig(:calendar_item, :relative_offset_unit).to_s.strip.presence || "minutes"

      if raw_value.blank?
        item.relative_offset_minutes = 0
        return
      end

      value = raw_value.to_f

      multiplier = case unit
                   when "minutes" then 1
                   when "hours" then 60
                   when "days" then 60 * 24
                   when "weeks" then 60 * 24 * 7
                   when "months" then 60 * 24 * 30
                   else 1
                   end

      item.relative_offset_minutes = (value * multiplier).to_i
    end

    def apply_timing_mode(item)
      mode = params.dig(:calendar_item, :timing_mode).to_s
      return if mode.blank?

      if mode == "absolute"
        item.relative_anchor_id = nil
        item.relative_offset_minutes = 0
        item.relative_before = false
        item.relative_to_anchor_end = false
      end
    end

    def run_scheduler
      Calendars::CascadeScheduler.new(@calendar).call
    end

    def default_calendar_start_time
      timezone = @calendar.timezone
      base_date = @event.starts_on || @event.ends_on || Date.current
      return unless timezone && base_date

      Time.use_zone(timezone) do
        Time.zone.local(base_date.year, base_date.month, base_date.day, 0, 0)
      end
    end

    def ensure_milestone_tag(create: true)
      scope = @calendar.event_calendar_tags.where("LOWER(name) = ?", "milestones")
      create ? scope.first_or_create(name: "Milestones") : scope.first
    end

    def load_dependents
      @dependent_items = @calendar.calendar_items
                                  .includes(:event_calendar_tags, :team_members, :relative_anchor)
                                  .where(relative_anchor_id: @item.id)
                                  .order(:starts_at, :position, :id)
    end
  end
end
