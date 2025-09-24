module Client
  class DesignsController < EventScopedController
    before_action :load_documents, only: %i[index create]

    def index
      @new_document = build_new_document
    end

    def create
      @new_document = build_new_document
      @new_document.assign_attributes(document_params)

      if @new_document.save
        redirect_to client_event_designs_path(@event), notice: "Upload received."
      else
        flash.now[:alert] = "Unable to save your upload. Please review the errors below."
        render :index, status: :unprocessable_content
      end
    end

    private

    def load_documents
      @planner_documents = @event.documents.latest.client_visible.where.not(source: :client_upload).order(:title)
      @client_documents = @event.documents.latest.where(source: :client_upload).order(updated_at: :desc)
    end

    def build_new_document
      @event.documents.new(source: :client_upload, client_visible: true)
    end

    def document_params
      params.require(:document).permit(:title, :storage_uri, :checksum, :size_bytes, :content_type, :logical_id)
    end
  end
end
