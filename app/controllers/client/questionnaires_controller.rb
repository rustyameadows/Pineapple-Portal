module Client
  class QuestionnairesController < EventScopedController
    before_action :set_questionnaire, only: %i[show mark_finished mark_in_progress]
    before_action :load_sections, only: :show

    def index
      @questionnaires = @event.questionnaires.client_visible.order(:title)
    end

    def show
    end

    def mark_finished
      if @questionnaire.update(status: Questionnaire::STATUSES[:finished])
        redirect_to client_event_questionnaire_path(@event, @questionnaire), notice: "Questionnaire marked as finished."
      else
        redirect_to client_event_questionnaire_path(@event, @questionnaire), alert: @questionnaire.errors.full_messages.to_sentence
      end
    end

    def mark_in_progress
      if @questionnaire.update(status: Questionnaire::STATUSES[:in_progress])
        redirect_to client_event_questionnaire_path(@event, @questionnaire), notice: "Questionnaire marked as in progress."
      else
        redirect_to client_event_questionnaire_path(@event, @questionnaire), alert: @questionnaire.errors.full_messages.to_sentence
      end
    end

    private

    def set_questionnaire
      @questionnaire = @event.questionnaires.client_visible.find(params[:id])
    end

    def load_sections
      @sections = @questionnaire.sections.includes(questions: :attachments).order(:position, :created_at)
    end
  end
end
