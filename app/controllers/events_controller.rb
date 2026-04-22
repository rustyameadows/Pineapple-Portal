class EventsController < ApplicationController
  include EventsSettingsPageSupport

  before_action :set_event, only: %i[show edit update destroy archive restore]

  def index
    @active_events = active_events_scope
    @archived_events = archived_events_scope
  end

  def show
    @questionnaires = @event.questionnaires.order(:title)
    @internal_event_links = @event.event_links.internal.ordered
  end

  def new
    @event = Event.new
  end

  def create
    @event = Event.new(event_params)

    if @event.save
      redirect_to @event, notice: "Event created."
    else
      render :new, status: :unprocessable_content
    end
  end

  def edit; end

  def update
    if @event.update(event_params)
      redirect_to safe_return_to(fallback: event_path(@event)), notice: "Event updated."
    elsif render_settings_page_for(params[:return_to])
      nil
    else
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    @event.destroy
    redirect_to events_path, notice: "Event deleted."
  end

  def archive
    if @event.archived?
      redirect_to safe_return_to(fallback: events_path), alert: "Event is already archived." and return
    end

    if @event.update(archived_at: Time.current)
      redirect_to safe_return_to(fallback: events_path), notice: "Event archived."
    else
      redirect_to safe_return_to(fallback: events_path), alert: @event.errors.full_messages.to_sentence
    end
  end

  def restore
    unless @event.archived?
      redirect_to safe_return_to(fallback: events_path), alert: "Event is already active." and return
    end

    if @event.update(archived_at: nil)
      redirect_to safe_return_to(fallback: events_path), notice: "Event restored."
    else
      redirect_to safe_return_to(fallback: events_path), alert: @event.errors.full_messages.to_sentence
    end
  end

  private

  def set_event
    @event = Event.find(params[:id])
  end

  def event_params
    params.require(:event).permit(
      :name,
      :starts_on,
      :ends_on,
      :location,
      :location_secondary,
      :event_photo_document_id,
      :financial_payments_enabled,
      :portal_slug,
      :guest_count,
      :attire,
      :style,
      :color_palette,
      :key_people_label,
      :social_media_policy,
      :parking_details,
      :getting_ready_details,
      :pineapple_team_meals
    )
  end

  def active_events_scope
    Event.active.order(Arel.sql("COALESCE(events.starts_on, events.updated_at, events.created_at) ASC"))
  end

  def archived_events_scope
    Event.archived.order(Arel.sql("COALESCE(events.archived_at, events.updated_at) DESC"))
  end
end
