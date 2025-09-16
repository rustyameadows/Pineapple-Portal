class QuestionsController < ApplicationController
  before_action :set_questionnaire, only: %i[new create]
  before_action :set_question, only: %i[edit update destroy]

  def new
    @question = @questionnaire.questions.new
  end

  def create
    @question = @questionnaire.questions.new(question_params)
    @question.position = next_position

    if @question.save
      redirect_to @questionnaire, notice: "Question added."
    else
      render :new, status: :unprocessable_content
    end
  end

  def edit; end

  def update
    if @question.update(question_params)
      redirect_to @question.questionnaire, notice: "Question updated."
    else
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    questionnaire = @question.questionnaire
    @question.destroy
    redirect_to questionnaire, notice: "Question removed."
  end

  private

  def set_questionnaire
    @questionnaire = Questionnaire.find(params[:questionnaire_id])
  end

  def set_question
    @question = Question.find(params[:id])
  end

  def question_params
    params.require(:question).permit(:prompt, :help_text, :response_type)
  end

  def next_position
    (@questionnaire.questions.maximum(:position) || 0) + 1
  end
end
