module Events
  class CalendarItemsController < ApplicationController
    before_action :set_event
    before_action :set_calendar
    before_action :set_item, only: %i[edit update destroy]
    before_action :load_form_support, only: %i[new edit create update]

    def new
      @item = @calendar.calendar_items.new
    end

    def create
      @item = @calendar.calendar_items.new(item_params)
      assign_tags(@item)

      if @item.save
        run_scheduler
        redirect_to event_calendar_path(@event), notice: "Calendar item added."
      else
        flash.now[:alert] = @item.errors.full_messages.to_sentence
        render :new, status: :unprocessable_content
      end
    end

    def edit; end

    def update
      assign_tags(@item)

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

    private

    def set_event
      @event = Event.find(params[:event_id])
    end

    def set_calendar
      @calendar = @event.run_of_show_calendar || @event.event_calendars.create!(
        name: "Run of Show",
        timezone: Time.zone.tzinfo&.identifier || Time.zone.name || "UTC"
      )
    end

    def set_item
      @item = @calendar.calendar_items.find(params[:id])
    end

    def load_form_support
      @available_tags = @calendar.event_calendar_tags.order(:position, :name)
      @anchor_options = (
        @calendar.calendar_items.order(:title).map do |item|
          next if @item && item.id == @item.id

          [anchor_label(item), item.id]
        end
      ).compact
    end

    def anchor_label(item)
      start = item.effective_starts_at&.in_time_zone(@calendar.timezone)
      time_label = start ? start.strftime("%b %-d %l:%M %p") : "TBD"
      "#{item.title} (#{time_label})"
    end

    def item_params
      params.require(:calendar_item).permit(
        :title,
        :notes,
        :duration_minutes,
        :starts_at,
        :relative_anchor_id,
        :relative_offset_minutes,
        :relative_before,
        :locked
      )
    end

    def assign_tags(item)
      tag_ids = Array(params.dig(:calendar_item, :event_calendar_tag_ids)).reject(&:blank?).map(&:to_i)
      item.event_calendar_tag_ids = tag_ids
    end

    def run_scheduler
      Calendars::CascadeScheduler.new(@calendar).call
    end
  end
end
