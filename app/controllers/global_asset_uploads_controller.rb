class GlobalAssetUploadsController < ApplicationController
  def create
    filename = params.require(:filename)
    content_type = params[:content_type].presence || "application/octet-stream"

    storage_key = GlobalAssetStorage.build_key(filename: filename)

    storage = R2::Storage.new
    upload_url = storage.presigned_upload_url(key: storage_key, content_type: content_type)

    render json: {
      upload_url: upload_url,
      storage_uri: storage_key,
      content_type: content_type
    }
  end
end
