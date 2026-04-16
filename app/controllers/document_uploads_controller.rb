class DocumentUploadsController < ApplicationController
  include ClientPortalAuthentication

  skip_before_action :require_login
  before_action :set_event
  before_action :authorize_presign!

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

  def authorize_presign!
    return if current_user.present?
    return if current_client_user.present? && client_can_access_event?(current_client_user, @event)

    reset_client_session if session[:client_user_id].present? && current_client_user.nil?

    render json: {
      error: current_client_user.present? ? "Access to this event is unavailable." : "Please sign in to upload files."
    }, status: current_client_user.present? ? :forbidden : :unauthorized
  end

  def set_event
    @event = Event.find(params[:event_id])
  end
end
