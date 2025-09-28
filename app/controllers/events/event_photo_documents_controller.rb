module Events
  class EventPhotoDocumentsController < ApplicationController
    before_action :set_event

    def create
      @document = @event.documents.new(document_params)
      @document.source ||= "staff_upload"

      unless @document.content_type.to_s.start_with?("image/")
        @document.errors.add(:content_type, "must be an image")
      end

      if @document.errors.none? && @document.save
        if @event.update(event_photo_document: @document)
          redirect_to event_settings_path(@event), notice: "Event photo updated."
        else
          message = @event.errors.full_messages.to_sentence.presence || "Image uploaded, but could not assign as event photo."
          redirect_to event_settings_path(@event), alert: message
        end
      else
        message = @document.errors.full_messages.to_sentence.presence || "Unable to upload image."
        redirect_to event_settings_path(@event), alert: message
      end
    end

    private

    def set_event
      @event = Event.find(params[:event_id])
    end

    def document_params
      params.require(:document).permit(
        :title,
        :storage_uri,
        :checksum,
        :size_bytes,
        :content_type,
        :logical_id,
        :client_visible,
        :source
      )
    end
  end
end
