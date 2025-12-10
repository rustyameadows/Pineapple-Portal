module Events
  class CalendarViewsController < ApplicationController
    helper CalendarHelper

    before_action :set_event
    before_action :set_calendar
    before_action :set_view, only: %i[show edit update destroy timeline_preview]
    before_action :load_tags, only: %i[new edit show]

    def show
      @filter = Calendars::ViewFilter.new(calendar: @calendar, view: @view)
      @items = @filter.items
    end

    def timeline_preview
      filter = Calendars::ViewFilter.new(calendar: @calendar, view: @view)
      @items = filter.items
      @items = if @items.respond_to?(:includes)
                 @items.includes(:event_calendar_tags, :team_members, :relative_anchor)
               else
                 @items.map do |item|
                   item.association(:event_calendar_tags).target
                   item.association(:team_members).target
                   item.association(:relative_anchor).target
                   item
                 end
               end
      @segment = Struct.new(:title, :html_options, :html_view_key).new(
        title: @view.name,
        html_options: { "view_ref" => @view.id },
        html_view_key: DocumentSegment::TIMELINE_VIEW_KEY
      )
      render template: "generated_documents/sections/timeline", layout: "generated_preview"
    end

    def new
      @view = @calendar.event_calendar_views.new
    end

    def create
      @view = @calendar.event_calendar_views.new(view_params)

      if @view.save
        redirect_to event_calendars_path(@event), notice: "Derived calendar created."
      else
        load_tags
        flash.now[:alert] = @view.errors.full_messages.to_sentence
        render :new, status: :unprocessable_content
      end
    end

    def edit; end

    def update
      if @view.update(view_params)
        redirect_to event_calendar_view_path(@event, @view), notice: "Derived calendar updated."
      else
        load_tags
        flash.now[:alert] = @view.errors.full_messages.to_sentence
        render :edit, status: :unprocessable_content
      end
    end

    def destroy
      @view.destroy
      redirect_to event_calendars_path(@event), notice: "Derived calendar removed."
    end

    def add_defaults
      created = 0
      existing_names = @calendar.event_calendar_views.pluck(:name).map { |n| n.to_s.downcase }
      existing_slugs = @calendar.event_calendar_views.pluck(:slug)
      tag_lookup = @calendar.event_calendar_tags.index_by { |tag| tag.name.to_s.downcase }
      missing_messages = []

      RunOfShowDefaultViews::VIEWS.each do |default_view|
        name = default_view[:name].to_s.strip
        next if name.blank?
        next if existing_names.include?(name.downcase)

        tag_names = Array(default_view[:tag_names]).map { |tag_name| tag_name.to_s.strip }.reject(&:blank?)
        tag_ids = tag_names.map { |tag_name| tag_lookup[tag_name.downcase]&.id }.compact
        missing = tag_names.reject { |tag_name| tag_lookup.key?(tag_name.downcase) }
        missing_messages << "#{name} missing tag#{'s' if missing.length > 1}: #{missing.join(', ')}" if missing.any?
        next if missing.any?

        view = @calendar.event_calendar_views.new(
          name:,
          slug: generate_unique_slug(name, existing_slugs),
          description: default_view[:description],
          hide_locked: default_view.fetch(:hide_locked, false),
          client_visible: default_view.fetch(:client_visible, false),
          tag_filter: tag_ids
        )

        if view.save
          created += 1
          existing_names << name.downcase
          existing_slugs << view.slug
        end
      end

      # Emit flash messages: one toast per missing default view; keep a single notice for adds/all-exist.
      if created.positive?
        flash[:notice] = "Added #{created} default timeline#{'s' if created != 1}."
      elsif missing_messages.empty?
        flash[:notice] = "All default timelines already exist."
      end

      missing_messages.each_with_index do |msg, index|
        flash[:"alert_#{index}"] = msg
      end

      redirect_to event_calendars_path(@event)
    rescue StandardError => e
      redirect_to event_calendars_path(@event), alert: "Could not add default timelines: #{e.message}"
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

    def set_view
      @view = @calendar.event_calendar_views.find(params[:id])
    end

    def load_tags
      @tags = @calendar.event_calendar_tags.order(:position)
      @tags_by_id = @tags.index_by(&:id)
    end

    def generate_unique_slug(name, existing_slugs)
      base = name.to_s.parameterize
      return base if base.blank? || !existing_slugs.include?(base)

      candidate = base
      suffix = 2
      while existing_slugs.include?(candidate)
        candidate = "#{base}-#{suffix}"
        suffix += 1
      end
      candidate
    end

    def view_params
      params.require(:event_calendar_view).permit(
        :name,
        :slug,
        :description,
        :hide_locked,
        :client_visible,
        tag_filter: []
      )
    end
  end
end
