module Client
  class QuestionAnswersController < PortalController
    before_action :set_questionnaire
    before_action :set_question

    def update
      if @questionnaire.template?
        redirect_to client_event_questionnaire_path(@event.portal_slug.presence || @event.id, @questionnaire), alert: "Templates cannot record answers."
        return
      end

      attrs = answer_params
      attrs[:answered_at] = attrs[:answer_value].present? ? Time.current : nil

      if @question.update(attrs)
        redirect_to client_event_questionnaire_path(@event.portal_slug.presence || @event.id, @questionnaire), notice: "Answer saved."
      else
        redirect_to client_event_questionnaire_path(@event.portal_slug.presence || @event.id, @questionnaire), alert: @question.errors.full_messages.to_sentence
      end
    end

    private

    def set_questionnaire
      @questionnaire = @event.questionnaires.client_visible.find(params[:questionnaire_id])
    end

    def set_question
      @question = @questionnaire.questions.find(params[:question_id])
    end

    def answer_params
      params.require(:question).permit(:answer_value)
    end
  end
end
