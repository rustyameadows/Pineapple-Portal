class AttachmentsController < ApplicationController
  before_action :set_attachment, only: %i[destroy]

  def create
    raw = attachment_params
    entity = find_entity(raw.delete(:entity_type), raw.delete(:entity_id))

    attrs = raw.slice(:document_id, :document_logical_id, :context, :position, :notes)
    attrs[:document_id] = attrs[:document_id].presence
    attrs[:document_logical_id] = attrs[:document_logical_id].presence

    attrs[:context] = if entity.is_a?(Question)
                        "answer"
                      else
                        attrs[:context].presence || "other"
                      end

    attrs[:position] = attrs[:position].presence || next_position_for(entity)

    upload_attrs = file_upload_params

    if upload_attrs.present?
      document = event_for_entity(entity).documents.new(upload_attrs)

      unless document.save
        attachment = entity.attachments.new(attrs)
        document.errors.full_messages.each { |msg| attachment.errors.add(:base, msg) }
        return respond_with_attachment(attachment, entity, success: false)
      end

      attrs[:document] = document
      attrs[:document_logical_id] = nil
    end

    attachment = entity.attachments.new(attrs)
    respond_with_attachment(attachment, entity, success: attachment.save)
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
    raw = params.require(:attachment).permit(
      :entity_type,
      :entity_id,
      :document_id,
      :document_logical_id,
      :context,
      :position,
      :notes,
      :file_upload_title,
      :file_upload_storage_uri,
      :file_upload_checksum,
      :file_upload_size_bytes,
      :file_upload_content_type,
      :file_upload_logical_id
    )
    raw[:entity_type] = safe_entity_type(raw[:entity_type])
    raw[:entity_id] = raw[:entity_id].presence && raw[:entity_id].to_i
    raise ActionController::BadRequest, "Missing entity" unless raw[:entity_id]
    raw[:document_id] = raw[:document_id].presence && raw[:document_id].to_i
    raw[:position] = raw[:position].presence && raw[:position].to_i
    raw.to_h.symbolize_keys
  end

  def safe_entity_type(value)
    allowed = %w[Event Questionnaire Question Payment Approval]
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
    ).to_h.symbolize_keys

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
    when Payment then entity.event
    when Approval then entity.event
    else
      raise ArgumentError, "Unsupported entity for attachment"
    end
  end

  def next_position_for(entity)
    entity.attachments.maximum(:position).to_i + 1
  end

  def respond_with_attachment(attachment, entity, success:)
    if success
      respond_to do |format|
        format.html do
          redirect_back fallback_location: root_path, notice: "Attachment added."
        end
        format.json { render json: attachment_json(attachment, entity), status: :created }
      end
    else
      message = attachment.errors.full_messages.to_sentence.presence || "Unable to add attachment."

      respond_to do |format|
        format.html do
          redirect_back fallback_location: root_path, alert: message
        end
        format.json { render json: { error: message }, status: :unprocessable_entity }
      end
    end
  end

  def attachment_json(attachment, entity)
    payload = { attachment_id: attachment.id }

    if entity.is_a?(Question)
      payload[:html] = render_to_string(
        partial: "client/questionnaires/attachment_chip",
        locals: { attachment: attachment, event: event_for_entity(entity) },
        formats: [:html]
      )
    end

    payload
  end
end
