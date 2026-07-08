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

    if anchor_date_required? && @anchor_date.blank?
      flash.now[:alert] = "Choose an anchor date to preview and import this timeline."
      return render(:new, status: :unprocessable_content)
    end

    result = Calendars::Commands::ImportItems.new(
      destination_event: @event,
      destination_calendar: @destination_calendar,
      source_event: @source_event,
      source_timeline_ref: @source_timeline_ref,
      selection_mode: selection_mode,
      selected_item_ids: @selected_item_ids,
      anchor_date: @anchor_date,
      batch_tag_enabled: @batch_tag_enabled
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
    @event = find_accessible_event!(params[:event_id])
  end

  def set_destination_calendar
    @destination_calendar = @event.run_of_show_calendar
    @destination_calendar ||= @event.event_calendars.create!(
      name: "Run of Show",
      timezone: EventCalendar::DEFAULT_TIMEZONE
    )
  end

  def load_source_events
    @source_events = accessible_events_scope.where.not(id: @event.id).order(:name)
  end

  def load_source_context
    @source_event = @source_events.find_by(id: params[:source_event_id])
    @source_calendar = @source_event&.run_of_show_calendar
    @timeline_options = build_timeline_options(@source_calendar)
    @source_timeline_ref = params[:source_timeline_ref].presence
    @source_timeline_ref ||= @timeline_options.first&.last if @source_event.present?
    @selection_mode = selection_mode
    @selected_item_ids = selected_item_ids_param
    @batch_tag_enabled = batch_tag_enabled_param
    @anchor_date = selected_anchor_date
    @anchor_date_value = selected_anchor_date_value
    @anchor_shift_supported = anchor_date_required?
    @destination_timezone_label = ActiveSupport::TimeZone[@destination_calendar.timezone]&.to_s || @destination_calendar.timezone
    @destination_tag_names = @destination_calendar.event_calendar_tags.order(:position, :name).pluck(:name)
    @expected_batch_tag_name = Calendars::ImportProjection.next_batch_tag_name(@destination_tag_names)
    @source_items = load_source_items
    @preview_items_payload = build_preview_items_payload(@source_items)
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

  def build_preview_items_payload(items)
    Array(items).map do |item|
      {
        id: item.id,
        title: item.title,
        position: item.position.to_i,
        relative_anchor_id: item.relative_anchor_id,
        relative_offset_minutes: item.relative_offset_minutes.to_i,
        relative_before: item.relative_before?,
        relative_to_anchor_end: item.relative_to_anchor_end?,
        duration_minutes: item.duration_minutes,
        time_caption: item.time_caption,
        source_starts_at: item.starts_at&.iso8601,
        source_effective_start: item.effective_starts_at&.iso8601,
        source_effective_end: item.effective_ends_at&.iso8601
      }
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

  def batch_tag_enabled_param
    ActiveModel::Type::Boolean.new.cast(params[:batch_tag_enabled])
  end

  def selected_anchor_date
    if params.key?(:anchor_date)
      parse_anchor_date(params[:anchor_date].presence)
    else
      default_anchor_date
    end
  end

  def selected_anchor_date_value
    return params[:anchor_date].presence if params.key?(:anchor_date)

    @anchor_date&.iso8601
  end

  def default_anchor_date
    @event.starts_on || @source_event&.starts_on
  end

  def anchor_date_required?
    @source_event&.starts_on.present?
  end

  def parse_anchor_date(value)
    return value if value.is_a?(Date)
    return nil if value.blank?

    Date.iso8601(value.to_s)
  rescue ArgumentError
    nil
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
    if result.batch_tag_name.present?
      messages << "Tagged this import batch as #{result.batch_tag_name}."
    end
    messages.join(" ")
  end
end
