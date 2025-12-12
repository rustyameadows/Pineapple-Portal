module Events
  class CalendarTagsController < ApplicationController
    before_action :set_event
    before_action :set_calendar
    before_action :set_tag, only: %i[update destroy]

    def create
      @tag = @calendar.event_calendar_tags.new(tag_params)

      if @tag.save
        redirect_to event_calendars_path(@event), notice: "Tag created."
      else
        redirect_to event_calendars_path(@event), alert: @tag.errors.full_messages.to_sentence
      end
    end

    def update
      if @tag.update(tag_params)
        redirect_to event_calendars_path(@event), notice: "Tag updated."
      else
        redirect_to event_calendars_path(@event), alert: @tag.errors.full_messages.to_sentence
      end
    end

    def destroy
      @tag.destroy
      redirect_to event_calendars_path(@event), notice: "Tag removed."
    end

    def add_defaults
      defaults = RunOfShowDefaults::TAGS
      existing_names = @calendar.event_calendar_tags.pluck(:name).map { |name| name.to_s.downcase }
      created = 0

      defaults.each do |tag|
        name = tag[:name].to_s.strip
        next if name.blank? || existing_names.include?(name.downcase)

        new_tag = @calendar.event_calendar_tags.create(name:, color_token: tag[:color_token])
        if new_tag.persisted?
          created += 1
          existing_names << name.downcase
        end
      end

      message = created.positive? ? "Added #{created} default tag#{'s' if created != 1}." : "All default tags already exist."
      redirect_to event_calendars_path(@event), notice: message
    rescue StandardError => e
      redirect_to event_calendars_path(@event), alert: "Could not add default tags: #{e.message}"
    end

    def restore_default_colors
      defaults = RunOfShowDefaults::TAGS.index_by { |tag| tag[:name].to_s.strip.downcase }
      updated = 0

      @calendar.event_calendar_tags.find_each do |tag|
        default = defaults[tag.name.to_s.strip.downcase]
        next unless default

        desired = default[:color_token].to_s.strip
        next if desired.blank?
        next if tag.color_token.to_s.strip == desired

        updated += 1 if tag.update(color_token: desired)
      end

      message = updated.positive? ? "Restored default colors for #{updated} tag#{'s' if updated != 1}." : "All tag colors already match defaults."
      redirect_to event_calendars_path(@event), notice: message
    rescue StandardError => e
      redirect_to event_calendars_path(@event), alert: "Could not restore default colors: #{e.message}"
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
