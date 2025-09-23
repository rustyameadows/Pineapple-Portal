class QuestionnaireSectionsController < ApplicationController
  before_action :set_event
  before_action :set_questionnaire
  before_action :set_section, only: %i[update destroy]

  def create
    @section = @questionnaire.sections.new(section_params)

    if @section.save
      redirect_to edit_event_questionnaire_path(@event, @questionnaire), notice: "Section added."
    else
      redirect_to edit_event_questionnaire_path(@event, @questionnaire), alert: @section.errors.full_messages.to_sentence
    end
  end

  def update
    if @section.update(section_params)
      redirect_to edit_event_questionnaire_path(@event, @questionnaire), notice: "Section updated."
    else
      redirect_to edit_event_questionnaire_path(@event, @questionnaire), alert: @section.errors.full_messages.to_sentence
    end
  end

  def destroy
    if @questionnaire.sections.count == 1
      redirect_to edit_event_questionnaire_path(@event, @questionnaire), alert: "You need at least one section."
      return
    end

    if @section.questions.exists?
      redirect_to edit_event_questionnaire_path(@event, @questionnaire), alert: "Remove or move questions before deleting this section."
      return
    end

    @section.destroy

    redirect_to edit_event_questionnaire_path(@event, @questionnaire), notice: "Section removed."
  end

  def reorder
    section_ids = Array(params[:section_ids])

    ActiveRecord::Base.transaction do
      section_ids.map(&:to_i).each_with_index do |id, index|
        @questionnaire.sections.where(id: id).update_all(position: index + 1)
      end
    end

    head :ok
  end

  private

  def set_event
    @event = Event.find(params[:event_id])
  end

  def set_questionnaire
    @questionnaire = @event.questionnaires.find(params[:questionnaire_id])
  end

  def set_section
    @section = @questionnaire.sections.find(params[:id])
  end

  def section_params
    params.require(:questionnaire_section).permit(:title, :helper_text)
  end
end
