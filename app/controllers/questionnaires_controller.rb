class QuestionnairesController < ApplicationController
  before_action :set_event, only: %i[new create]
  before_action :set_questionnaire, only: %i[show edit update destroy]

  def show
    @event = @questionnaire.event
    @questions = @questionnaire.questions.order(:position)
  end

  def new
    @questionnaire = @event.questionnaires.new
    @form_url = event_questionnaires_path(@event)
  end

  def create
    @questionnaire = @event.questionnaires.new(questionnaire_params)
    @form_url = event_questionnaires_path(@event)

    if @questionnaire.save
      redirect_to @questionnaire, notice: "Questionnaire created."
    else
      render :new, status: :unprocessable_content
    end
  end

  def edit
    @form_url = questionnaire_path(@questionnaire)
  end

  def update
    @form_url = questionnaire_path(@questionnaire)
    if @questionnaire.update(questionnaire_params)
      redirect_to @questionnaire, notice: "Questionnaire updated."
    else
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    event = @questionnaire.event
    @questionnaire.destroy
    redirect_to event_path(event), notice: "Questionnaire deleted."
  end

  def templates
    @questionnaires = Questionnaire.templates.order(:title)
  end

  private

  def set_event
    @event = Event.find(params[:event_id])
  end

  def set_questionnaire
    @questionnaire = Questionnaire.find(params[:id])
  end

  def questionnaire_params
    params.require(:questionnaire).permit(:title, :description, :is_template)
  end
end
