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
      preselected_tag_ids = []

      if params[:milestone] == "1"
        milestone_tag = ensure_milestone_tag
        preselected_tag_ids << milestone_tag.id if milestone_tag
      end

      default_tag = find_default_tag_by_name(params[:default_tag_name])
      preselected_tag_ids << default_tag.id if default_tag

      @item.event_calendar_tag_ids = preselected_tag_ids.uniq if preselected_tag_ids.any?
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
        redirect_to safe_return_to(fallback: event_calendar_path(@event)), notice: "Calendar item added."
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
        redirect_to safe_return_to(fallback: event_calendar_path(@event)), notice: "Calendar item updated."
      else
        flash.now[:alert] = @item.errors.full_messages.to_sentence
        render :edit, status: :unprocessable_content
      end
    end

    def bulk_update
      ids = Array(params[:item_ids]).map(&:to_i).reject(&:zero?)
      result = Calendars::GridBulkUpdater.new(
        calendar: @calendar,
        item_ids: ids,
        params: bulk_params
      ).call

      flash_key = result.success? ? :notice : :alert
      redirect_to safe_return_to(fallback: event_calendar_path(@event)),
                  flash: { flash_key => result.message }
    end

    def destroy
      @item.destroy
      run_scheduler
      redirect_to safe_return_to(fallback: event_calendar_path(@event)), notice: "Calendar item removed."
    end

    def mark_completed
      if @item.update(status: :completed)
        redirect_to safe_return_to(fallback: event_settings_path(@event)), notice: "Milestone marked as completed."
      else
        redirect_to safe_return_to(fallback: event_settings_path(@event)), alert: @item.errors.full_messages.to_sentence
      end
    end

    def mark_planned
      if @item.update(status: :planned)
        redirect_to safe_return_to(fallback: event_settings_path(@event)), notice: "Milestone reopened."
      else
        redirect_to safe_return_to(fallback: event_settings_path(@event)), alert: @item.errors.full_messages.to_sentence
      end
    end

    def remove_milestone_tag
      milestone_tag = ensure_milestone_tag(create: false)
      if milestone_tag
        @item.calendar_item_tags.where(event_calendar_tag: milestone_tag).destroy_all
        redirect_to safe_return_to(fallback: event_settings_path(@event)), notice: "Milestone tag removed."
      else
        redirect_to safe_return_to(fallback: event_settings_path(@event)), alert: "Milestone tag not found."
      end
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

    def set_item
      @item = @calendar.calendar_items.find(params[:id])
    end

    def load_form_support
      @available_tags = @calendar.event_calendar_tags.order(Arel.sql("LOWER(name) ASC"))
      @available_team_members = @event.team_members.where.not(role: User::ROLES[:client]).order(:name)
      @anchor_options = (
        @calendar.calendar_items.order(:title).map do |item|
          next if @item && item.id == @item.id

          [anchor_label(item), item.id, anchor_option_attributes(item)]
        end
      ).compact
      @default_start_time = default_calendar_start_time
    end

    def anchor_label(item)
      start = item.effective_starts_at&.in_time_zone(@calendar.timezone)
      finish = item.effective_ends_at&.in_time_zone(@calendar.timezone)
      time_label = if start && finish
                     "#{start.strftime('%b %-d %-l:%M %p')} – #{finish.strftime('%-l:%M %p')}"
                   elsif start
                     start.strftime("%b %-d %-l:%M %p")
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

    def item_params
      params.require(:calendar_item).permit(
        :title,
        :notes,
        :starts_at,
        :relative_anchor_id,
        :relative_before,
        :locked,
        :relative_to_anchor_end,
        :vendor_name,
        :location_name,
        :status,
        :additional_team_members,
        :guest_count,
        :time_caption,
        :transportation_note,
        team_member_ids: []
      )
    end

    def bulk_params
      params.fetch(:bulk, {}).permit(
        :bulk_action,
        :vendor_name,
        :location_name,
        :time_caption,
        :additional_team_members,
        tag_ids: [],
        team_member_ids: []
      )
    end

    def assign_tags(item)
      tag_ids = Array(params.dig(:calendar_item, :event_calendar_tag_ids)).reject(&:blank?).map(&:to_i)
      item.event_calendar_tag_ids = tag_ids
    end

    def assign_team_members(item)
      member_ids = Array(params.dig(:calendar_item, :team_member_ids)).reject(&:blank?).map(&:to_i)
      allowed_ids = @event.team_members.where.not(role: User::ROLES[:client]).where(id: member_ids).pluck(:id)
      item.team_member_ids = allowed_ids
    end

    def assign_duration(item)
      return unless time_amount_params_present?(:duration)

      amount = time_amount_from_params(:duration, nullable: true)
      item.duration_minutes = amount.total_minutes
      item.duration_display_value = amount.value
      item.duration_display_unit = amount.unit
      item.duration_display_hours = amount.hours
      item.duration_display_minutes = amount.minutes
    end

    def assign_offset(item)
      return unless time_amount_params_present?(:relative_offset)

      amount = time_amount_from_params(:relative_offset)
      item.relative_offset_minutes = amount.total_minutes
      item.relative_offset_display_value = amount.value
      item.relative_offset_display_unit = amount.unit
      item.relative_offset_display_hours = amount.hours
      item.relative_offset_display_minutes = amount.minutes
    end

    def apply_timing_mode(item)
      mode = params.dig(:calendar_item, :timing_mode).to_s
      return if mode.blank?

      if mode == "absolute"
        item.relative_anchor_id = nil
        item.relative_offset_minutes = 0
        item.relative_offset_display_value = 0
        item.relative_offset_display_unit = "days"
        item.relative_offset_display_hours = 0
        item.relative_offset_display_minutes = 0
        item.relative_before = false
        item.relative_to_anchor_end = false
      end
    end

    def time_amount_from_params(prefix, nullable: false)
      if display_time_amount_params_present?(prefix)
        return Calendars::TimeAmount.from_display(
          value: params.dig(:calendar_item, :"#{prefix}_display_value"),
          unit: params.dig(:calendar_item, :"#{prefix}_display_unit"),
          hours: params.dig(:calendar_item, :"#{prefix}_display_hours"),
          minutes: params.dig(:calendar_item, :"#{prefix}_display_minutes"),
          nullable:
        )
      end

      legacy_time_amount_from_params(prefix, nullable:)
    end

    def time_amount_params_present?(prefix)
      display_time_amount_params_present?(prefix) || legacy_time_amount_params_present?(prefix)
    end

    def display_time_amount_params_present?(prefix)
      calendar_item_params_hash.key?(:"#{prefix}_display_value") ||
        calendar_item_params_hash.key?(:"#{prefix}_display_unit") ||
        calendar_item_params_hash.key?(:"#{prefix}_display_hours") ||
        calendar_item_params_hash.key?(:"#{prefix}_display_minutes")
    end

    def legacy_time_amount_params_present?(prefix)
      calendar_item_params_hash.key?(:"#{prefix}_value") || calendar_item_params_hash.key?(:"#{prefix}_unit")
    end

    def legacy_time_amount_from_params(prefix, nullable:)
      raw_value = params.dig(:calendar_item, :"#{prefix}_value").to_s.strip
      unit = params.dig(:calendar_item, :"#{prefix}_unit").to_s.strip
      return Calendars::TimeAmount.from_display(value: "", unit: "days", hours: "", minutes: "", nullable:) if raw_value.blank?

      multiplier = case unit
                   when "hours" then 60
                   when "days" then 60 * 24
                   when "weeks" then 60 * 24 * 7
                   when "months" then 60 * 24 * 30
                   else 1
                   end
      preferred_unit = unit.in?(Calendars::TimeAmount::MAJOR_UNITS.keys) ? unit : "days"

      Calendars::TimeAmount.from_minutes((raw_value.to_f * multiplier).to_i, preferred_unit:, nullable:)
    end

    def calendar_item_params_hash
      params.fetch(:calendar_item, {})
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

    def find_default_tag_by_name(raw_name)
      normalized_name = raw_name.to_s.strip.downcase
      return if normalized_name.blank?

      @calendar.event_calendar_tags.where("LOWER(name) = ?", normalized_name).first
    end

    def load_dependents
      @dependent_items = @calendar.calendar_items
                                  .includes(:event_calendar_tags, :team_members, :relative_anchor)
                                  .where(relative_anchor_id: @item.id)
                                  .order(:starts_at, :position, :id)
    end
  end
end
