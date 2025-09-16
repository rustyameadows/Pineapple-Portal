class DocumentUploadsController < ApplicationController
  before_action :set_event

  def create
    filename = params.require(:filename)
    content_type = params[:content_type].presence || "application/octet-stream"
    logical_id = params[:logical_id].presence || SecureRandom.uuid

    version = if Document.exists?(logical_id: logical_id)
                Document.next_version_for(logical_id)
              else
                1
              end

    storage_key = DocumentStorage.build_key(event: @event, logical_id: logical_id, version: version, filename: filename)

    storage = R2::Storage.new
    upload_url = storage.presigned_upload_url(key: storage_key, content_type: content_type)

    render json: {
      upload_url: upload_url,
      storage_uri: storage_key,
      logical_id: logical_id,
      version: version,
      content_type: content_type
    }
  end

  private

  def set_event
    @event = Event.find(params[:event_id])
  end
end
