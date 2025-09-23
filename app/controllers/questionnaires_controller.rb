class QuestionnairesController < ApplicationController
  before_action :set_event
  before_action :set_questionnaire, only: %i[show edit update destroy]
  before_action :load_sections, only: %i[show edit]

  def index
    @questionnaires = @event.questionnaires.order(:title)
  end

  def show
  end

  def new
    @questionnaire = @event.questionnaires.new
    @questionnaire.sections.build(title: "Section 1") if @questionnaire.sections.blank?
  end

  def create
    @questionnaire = @event.questionnaires.new(questionnaire_params)

    if @questionnaire.save
      redirect_to event_questionnaire_path(@event, @questionnaire), notice: "Questionnaire created."
    else
      render :new, status: :unprocessable_content
    end
  end

  def edit; end

  def update
    if @questionnaire.update(questionnaire_params)
      redirect_to event_questionnaire_path(@event, @questionnaire), notice: "Questionnaire updated."
    else
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    @questionnaire.destroy
    redirect_to event_path(@event), notice: "Questionnaire deleted."
  end

  def templates
    @questionnaires = Questionnaire.templates.order(:title)
  end

  private

  def set_event
    @event = Event.find(params[:event_id]) if params[:event_id].present?
  end

  def set_questionnaire
    @questionnaire = if @event
                        @event.questionnaires.find(params[:id])
                      else
                        Questionnaire.find(params[:id])
                      end
    @event ||= @questionnaire.event
  end

  def questionnaire_params
    params.require(:questionnaire).permit(:title, :description, :is_template,
                                          sections_attributes: %i[id title helper_text position _destroy])
  end

  def load_sections
    @sections = @questionnaire.sections.includes(questions: :attachments)
  end
end
