module Client
  class DesignsController < PortalController
    def index
      @gallery_documents = client_gallery_documents
      @display_documents = planner_documents
      @document = build_document
    end

    def create
      @document = build_document
      @document.assign_attributes(document_params)
      @document.client_visible = true

      if @document.save
        redirect_to client_event_designs_path(@event.portal_slug.presence || @event.id), notice: "Upload received."
      else
        @display_documents = planner_documents
        @gallery_documents = client_gallery_documents
        render :index, status: :unprocessable_content
      end
    end

    private

    def planner_documents
      @planner_documents ||= @event.documents
                                   .latest
                                   .client_visible
                                   .where.not(source: "client_upload")
                                   .order(:title)
    end

    def client_gallery_documents
      @client_gallery_documents ||= @event.documents
                                           .latest
                                           .where(source: "client_upload")
                                           .where("content_type LIKE ?", "image/%")
                                           .order(updated_at: :desc)
    end

    def build_document
      @event.documents.new(source: "client_upload", client_visible: true)
    end

    def document_params
      params.require(:document).permit(:title, :storage_uri, :checksum, :size_bytes, :content_type, :logical_id)
    end
  end
end
