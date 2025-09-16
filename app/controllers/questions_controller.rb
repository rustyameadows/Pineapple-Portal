class QuestionsController < ApplicationController
  before_action :set_event
  before_action :set_questionnaire, only: %i[new create reorder]
  before_action :set_question, only: %i[edit update destroy answer]

  def new
    @question = @questionnaire.questions.new
  end

  def create
    @question = @questionnaire.questions.new(question_params)
    @question.position = next_position

    if @question.save
      redirect_to event_questionnaire_path(@event, @questionnaire), notice: "Question added."
    else
      render :new, status: :unprocessable_content
    end
  end

  def edit; end

  def update
    if @question.update(question_params)
      redirect_to event_questionnaire_path(@event, @question.questionnaire), notice: "Question updated."
    else
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    questionnaire = @question.questionnaire
    @question.destroy
    redirect_to event_questionnaire_path(@event, questionnaire), notice: "Question removed."
  end

  def answer
    if @questionnaire.template?
      redirect_to event_questionnaire_path(@event, @questionnaire), alert: "Templates cannot record answers."
      return
    end

    attrs = answer_params.to_h.symbolize_keys
    upload_attrs = extract_upload_attrs(attrs)
    attrs[:answered_at] = attrs[:answer_value].present? ? Time.current : nil

    ApplicationRecord.transaction do
      unless @question.update(attrs)
        raise ActiveRecord::Rollback
      end

      if upload_attrs.present?
        document = @event.documents.create!(upload_attrs)
        @question.attachments.create!(document: document, context: :answer, position: next_attachment_position(@question))
      end
    end

    redirect_to event_questionnaire_path(@event, @questionnaire), notice: "Answer saved."
  rescue ActiveRecord::RecordInvalid => e
    redirect_to event_questionnaire_path(@event, @questionnaire), alert: e.message
  end

  def reorder
    ids = Array(params[:order])

    ActiveRecord::Base.transaction do
      ids.map(&:to_i).each_with_index do |id, index|
        @questionnaire.questions.where(id: id).update_all(position: index + 1)
      end
    end

    head :ok
  end

  private

  def set_event
    @event = Event.find(params[:event_id]) if params[:event_id].present?
  end

  def set_questionnaire
    @questionnaire = @event.questionnaires.find(params[:questionnaire_id])
  end

  def set_question
    @questionnaire = @event.questionnaires.find(params[:questionnaire_id])
    @question = @questionnaire.questions.find(params[:id])
  end

  def question_params
    params.require(:question).permit(:prompt, :help_text, :response_type)
  end

  def next_position
    (@questionnaire.questions.maximum(:position) || 0) + 1
  end

  def answer_params
    params.require(:question).permit(:answer_value, :file_storage_uri, :file_checksum, :file_size_bytes, :file_content_type, :file_title, :file_logical_id)
  end

  def extract_upload_attrs(attrs)
    keys = %i[file_storage_uri file_checksum file_size_bytes file_content_type file_title file_logical_id]
    data = keys.index_with { |key| attrs.delete(key) }
    storage_uri = data[:file_storage_uri].presence
    return nil unless storage_uri

    {
      title: data[:file_title].presence || File.basename(storage_uri),
      storage_uri: storage_uri,
      checksum: data[:file_checksum],
      size_bytes: data[:file_size_bytes].to_i,
      content_type: data[:file_content_type].presence || "application/octet-stream",
      logical_id: data[:file_logical_id].presence || SecureRandom.uuid
    }
  end

  def next_attachment_position(question)
    question.attachments.maximum(:position).to_i + 1
  end
end
