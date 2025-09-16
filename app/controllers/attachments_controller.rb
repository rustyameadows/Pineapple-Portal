class AttachmentsController < ApplicationController
  before_action :set_attachment, only: %i[destroy]

  def create
    @attachment = Attachment.new(attachment_params)
    upload_attrs = file_upload_params

    if upload_attrs.present?
      entity = find_entity(@attachment.entity_type, @attachment.entity_id)
      event = event_for_entity(entity)

      document = event.documents.new(upload_attrs)

      if document.save
        @attachment.document = document
        @attachment.document_logical_id = nil
      else
        document.errors.full_messages.each { |msg| @attachment.errors.add(:base, msg) }
      end
    end

    if @attachment.errors.empty? && @attachment.save
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
    raw[:document_id] = raw[:document_id].present? ? raw[:document_id].to_i : nil
    raw
  end

  def safe_entity_type(value)
    allowed = %w[Event Questionnaire Question]
    return value if allowed.include?(value)

    raise ActionController::BadRequest, "Unsupported entity_type"
  end

  def file_upload_params
    permitted = params.require(:attachment).permit(
      :file_upload_title,
      :file_upload_storage_uri,
      :file_upload_checksum,
      :file_upload_size_bytes,
      :file_upload_content_type,
      :file_upload_logical_id
    )

    storage_uri = permitted[:file_upload_storage_uri].presence
    return if storage_uri.blank?

    {
      title: permitted[:file_upload_title].presence || File.basename(storage_uri),
      storage_uri: storage_uri,
      checksum: permitted[:file_upload_checksum],
      size_bytes: permitted[:file_upload_size_bytes].to_i,
      content_type: permitted[:file_upload_content_type].presence || "application/octet-stream",
      logical_id: permitted[:file_upload_logical_id].presence || SecureRandom.uuid
    }
  end

  def find_entity(type, id)
    type.constantize.find(id)
  end

  def event_for_entity(entity)
    case entity
    when Event then entity
    when Questionnaire then entity.event
    when Question then entity.event
    else
      raise ArgumentError, "Unsupported entity for attachment"
    end
  end
end
