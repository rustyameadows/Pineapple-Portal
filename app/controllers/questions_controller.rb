class QuestionsController < ApplicationController
  before_action :set_event
  before_action :set_questionnaire, only: %i[new create reorder]
  before_action :set_question, only: %i[edit update destroy answer]
  before_action :load_sections, only: %i[new create edit update]

  def new
    default_section_id = params[:section_id].presence || @questionnaire.sections.first&.id
    @question = @questionnaire.questions.new(questionnaire_section_id: default_section_id)
  end

  def create
    @question = @questionnaire.questions.new(question_params)
    @question.questionnaire_section_id ||= @questionnaire.sections.first&.id
    @question.position = next_position(@question.questionnaire_section_id)

    if @question.save
      redirect_to event_questionnaire_path(@event, @questionnaire), notice: "Question added."
    else
      render :new, status: :unprocessable_content
    end
  end

  def edit; end

  def update
    old_section_id = @question.questionnaire_section_id
    if @question.update(question_params)
      new_section_id = @question.questionnaire_section_id
      if @question.previous_changes.key?("questionnaire_section_id")
        @question.update(position: next_position(new_section_id))
        normalize_section_positions(old_section_id)
      end
      normalize_section_positions(new_section_id)
      redirect_to event_questionnaire_path(@event, @question.questionnaire), notice: "Question updated."
    else
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    questionnaire = @question.questionnaire
    section_id = @question.questionnaire_section_id
    @question.destroy
    normalize_section_positions(section_id)
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
    raw_orders = params[:section_orders]
    section_orders =
      case raw_orders
      when ActionController::Parameters
        raw_orders.to_unsafe_h
      when Hash
        raw_orders
      else
        {}
      end

    ActiveRecord::Base.transaction do
      section_orders.each do |section_id, question_ids|
        question_ids = Array(question_ids)
        section = @questionnaire.sections.find(section_id)

        question_ids.map(&:to_i).each_with_index do |id, index|
          question = @questionnaire.questions.find(id)
          question.update_columns(
            questionnaire_section_id: section.id,
            position: index + 1,
            updated_at: Time.current
          )
        end
        normalize_section_positions(section.id)
      end
    end

    head :ok
  rescue ActiveRecord::RecordInvalid => e
    render json: { error: e.record.errors.full_messages.to_sentence }, status: :unprocessable_entity
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
    params.require(:question).permit(:prompt, :help_text, :response_type, :questionnaire_section_id)
  end

  def next_position(section_id)
    section_id = section_id.presence || @questionnaire.sections.first&.id
    return 1 unless section_id

    @questionnaire.questions.where(questionnaire_section_id: section_id).maximum(:position).to_i + 1
  end

  def load_sections
    @sections = if @questionnaire
                  @questionnaire.sections
                else
                  @question.questionnaire.sections
                end
  end

  def normalize_section_positions(section_id)
    return unless section_id

    questions = @questionnaire.questions.where(questionnaire_section_id: section_id).order(:position, :updated_at)
    questions.each_with_index do |question, index|
      question.update_column(:position, index + 1)
    end
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
