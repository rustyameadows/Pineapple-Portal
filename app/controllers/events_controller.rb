class EventsController < ApplicationController
  before_action :set_event, only: %i[show edit update destroy]

  def index
    @active_events = Event.active.order(Arel.sql("COALESCE(events.starts_on, events.updated_at, events.created_at) ASC"))
    @archived_events = Event.archived.order(updated_at: :desc)
  end

  def show
    @questionnaires = @event.questionnaires.order(:title)
    @event_links = @event.event_links.quick.ordered
    @payments = @event.payments.ordered
    @approvals = @event.approvals.ordered
    @calendar = @event.run_of_show_calendar
    @calendar_views = @calendar&.event_calendar_views&.order(:position)
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
      redirect_to @event, notice: "Event updated."
    else
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    @event.destroy
    redirect_to events_path, notice: "Event deleted."
  end

  private

  def set_event
    @event = Event.find(params[:id])
  end

  def event_params
    params.require(:event).permit(:name, :starts_on, :ends_on, :location, :event_photo_document_id)
  end
end
