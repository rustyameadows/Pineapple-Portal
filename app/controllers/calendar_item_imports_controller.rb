class CalendarItemImportsController < ApplicationController
  before_action :set_event
  before_action :set_destination_calendar
  before_action :load_source_events
  before_action :load_source_context

  def new
  end

  def create
    unless @source_event
      flash.now[:alert] = "Select a source event to import from."
      return render(:new, status: :unprocessable_content)
    end

    unless timeline_ref_valid?
      flash.now[:alert] = "Select a source timeline."
      return render(:new, status: :unprocessable_content)
    end

    if selection_mode == "selected" && @selected_item_ids.empty?
      flash.now[:alert] = "Select at least one item to import."
      return render(:new, status: :unprocessable_content)
    end

    result = Calendars::Commands::ImportItems.new(
      destination_event: @event,
      destination_calendar: @destination_calendar,
      source_event: @source_event,
      source_timeline_ref: @source_timeline_ref,
      selection_mode: selection_mode,
      selected_item_ids: @selected_item_ids
    ).call

    redirect_to event_calendar_path(@event), notice: build_notice(result)
  rescue Calendars::Commands::ImportItems::InvalidSource, Calendars::Commands::ImportItems::InvalidSelection => e
    flash.now[:alert] = e.message
    render :new, status: :unprocessable_content
  rescue ActiveRecord::RecordInvalid => e
    flash.now[:alert] = "Unable to import items: #{e.record.errors.full_messages.to_sentence}"
    render :new, status: :unprocessable_content
  end

  private

  def set_event
    @event = Event.find(params[:event_id])
  end

  def set_destination_calendar
    @destination_calendar = @event.run_of_show_calendar
    @destination_calendar ||= @event.event_calendars.create!(
      name: "Run of Show",
      timezone: EventCalendar::DEFAULT_TIMEZONE
    )
  end

  def load_source_events
    @source_events = Event.where.not(id: @event.id).order(:name)
  end

  def load_source_context
    @source_event = @source_events.find_by(id: params[:source_event_id])
    @source_calendar = @source_event&.run_of_show_calendar
    @timeline_options = build_timeline_options(@source_calendar)
    @source_timeline_ref = params[:source_timeline_ref].presence
    @source_timeline_ref ||= @timeline_options.first&.last if @source_event.present?
    @selection_mode = selection_mode
    @selected_item_ids = selected_item_ids_param
    @source_items = load_source_items
  end

  def build_timeline_options(source_calendar)
    return [] unless source_calendar

    options = [["Run of Show", "run_of_show"]]
    source_calendar.event_calendar_views.order(:position, :name).each do |view|
      options << [view.name, "view:#{view.id}"]
    end
    options
  end

  def load_source_items
    return [] unless @source_calendar
    return [] unless @source_timeline_ref.present?
    return [] unless timeline_ref_valid?

    case @source_timeline_ref
    when "run_of_show"
      @source_calendar.calendar_items
                      .includes(:event_calendar_tags, :relative_anchor, :team_members)
                      .ordered
                      .to_a
    else
      view_id = @source_timeline_ref.delete_prefix("view:").to_i
      view = @source_calendar.event_calendar_views.find_by(id: view_id)
      return [] unless view

      Array(Calendars::ViewFilter.new(calendar: @source_calendar, view: view).items)
    end
  end

  def timeline_ref_valid?
    @timeline_options.any? { |(_label, value)| value == @source_timeline_ref }
  end

  def selection_mode
    params[:selection_mode].to_s == "all" ? "all" : "selected"
  end

  def selected_item_ids_param
    Array(params[:item_ids]).map(&:to_i).reject(&:zero?)
  end

  def build_notice(result)
    messages = ["Imported #{result.imported_count} #{'item'.pluralize(result.imported_count)}."]
    if result.fallback_to_absolute_count.positive?
      messages << "Converted #{result.fallback_to_absolute_count} #{'item'.pluralize(result.fallback_to_absolute_count)} to absolute time because anchor items were not selected."
    end
    if result.missing_time_count.positive?
      messages << "#{result.missing_time_count} #{'item'.pluralize(result.missing_time_count)} imported without a start time because no effective source time was available."
    end
    if result.created_tag_count.positive?
      messages << "Created #{result.created_tag_count} new #{'tag'.pluralize(result.created_tag_count)}."
    end
    messages.join(" ")
  end
end
