module Client
  class QuestionnairesController < EventScopedController
    before_action :set_questionnaire, only: :show
    before_action :load_sections, only: :show

    def index
      @questionnaires = @event.questionnaires.client_visible.order(:title)
    end

    def show
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
