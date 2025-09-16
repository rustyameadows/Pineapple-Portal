class EventsController < ApplicationController
  before_action :set_event, only: %i[show edit update destroy]

  def index
    @events = Event.order(:starts_on, :name)
  end

  def show
    @questionnaires = @event.questionnaires.order(:title)
    @templates = Questionnaire.templates.order(:title)
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
    params.require(:event).permit(:name, :starts_on, :ends_on, :location)
  end
end
