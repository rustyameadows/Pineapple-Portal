require "json"

class UploadFailuresController < ApplicationController
  skip_before_action :require_login

  def create
    payload = upload_failure_params.to_h.symbolize_keys
    payload[:request_id] = request.request_id
    payload[:remote_ip] = request.remote_ip
    payload[:user_id] = current_user&.id
    payload[:client_user_id] = session[:client_user_id]
    payload.compact!

    Rails.logger.warn("direct_upload_failure #{payload.to_json}")
    ActiveSupport::Notifications.instrument("direct_upload.failure_reported", payload)

    head :accepted
  end

  private

  def upload_failure_params
    params.permit(
      :scope,
      :stage,
      :path,
      :presign_url,
      :event_id,
      :storage_uri,
      :logical_id,
      :status,
      :response_text,
      :message,
      :user_agent,
      :attachments_path,
      :entity_type,
      :entity_id
    )
  end
end
