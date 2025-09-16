class AttachmentsController < ApplicationController
  before_action :set_attachment, only: %i[destroy]

  def create
    @attachment = Attachment.new(attachment_params)

    if @attachment.save
      redirect_back fallback_location: root_path, notice: "Attachment added."
    else
      redirect_back fallback_location: root_path, alert: @attachment.errors.full_messages.to_sentence
    end
  end

  def destroy
    @attachment.destroy
    redirect_back fallback_location: root_path, notice: "Attachment removed."
  end

  private

  def set_attachment
    @attachment = Attachment.find(params[:id])
  end

  def attachment_params
    raw = params.require(:attachment).permit(:entity_type, :entity_id, :document_id, :document_logical_id, :context, :position, :notes)
    raw[:entity_type] = safe_entity_type(raw[:entity_type])
    raw[:entity_id] = raw[:entity_id].present? ? raw[:entity_id].to_i : nil
    raw
  end

  def safe_entity_type(value)
    allowed = %w[Event Questionnaire Question]
    return value if allowed.include?(value)

    raise ActionController::BadRequest, "Unsupported entity_type"
  end
end
