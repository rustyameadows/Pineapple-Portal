class QuestionnaireImportsController < ApplicationController
  before_action :set_event
  before_action :load_form_collections, only: %i[new create]

  def new
  end

  def create
    @source_event = Event.find_by(id: params[:source_event_id])
    @source_questionnaire = @source_event&.questionnaires&.find_by(id: params[:source_questionnaire_id])

    unless @source_questionnaire
      flash.now[:alert] = "Select a source questionnaire to import."
      return render(:new, status: :unprocessable_content)
    end

    if params[:import_mode] == "append"
      destination = @event.questionnaires.find_by(id: params[:destination_questionnaire_id])
      unless destination
        flash.now[:alert] = "Select a destination questionnaire to add questions to."
        return render(:new, status: :unprocessable_content)
      end

      @source_questionnaire.append_to!(destination)
      redirect_to event_questionnaire_path(@event, destination), notice: "Questions added to #{destination.title}."
    else
      title = params[:new_title].presence || @source_questionnaire.title
      imported = @source_questionnaire.duplicate_to_event!(@event, title: title)
      redirect_to event_questionnaire_path(@event, imported), notice: "Questionnaire imported."
    end
  end

  private

  def set_event
    @event = Event.find(params[:event_id])
  end

  def load_form_collections
    @events = Event.order(:name)
    @source_event = Event.find_by(id: params[:source_event_id]) if params[:source_event_id].present?
    @source_questionnaires = @source_event ? @source_event.questionnaires.order(:title) : []
    @questionnaires = @event.questionnaires.order(:title)
  end
end
