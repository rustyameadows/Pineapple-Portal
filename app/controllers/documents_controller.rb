class DocumentsController < ApplicationController
  before_action :set_event
  before_action :set_document, only: %i[show edit update destroy download]

  def index
    @documents = @event.documents.order(:title, :version)
  end

  def show
    @attachments = @document.attachments.includes(:entity).order(:context, :position)
    @available_entities = available_entities_for(@event)
    @versions = Document.where(logical_id: @document.logical_id).order(version: :desc)
  end

  def new
    @document = @event.documents.new
    @document.logical_id = params[:logical_id] if params[:logical_id].present?
  end

  def create
    @document = @event.documents.new(document_params)

    if @document.save
      redirect_to event_document_path(@event, @document), notice: "Document saved."
    else
      render :new, status: :unprocessable_content
    end
  end

  def edit
  end

  def update
    if @document.update(edit_document_params)
      redirect_to event_document_path(@event, @document), notice: "Document updated."
    else
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    @document.destroy
    redirect_to event_documents_path(@event), notice: "Document deleted."
  end

  def download
    storage = R2::Storage.new
    redirect_to storage.presigned_download_url(key: @document.storage_uri), allow_other_host: true
  end

  private

  def set_event
    @event = Event.find(params[:event_id])
  end

  def set_document
    @document = @event.documents.find(params[:id])
  end

  def document_params
    params.require(:document).permit(:title, :storage_uri, :checksum, :size_bytes, :content_type, :logical_id, :client_visible)
  end

  def edit_document_params
    params.require(:document).permit(:title, :content_type, :client_visible)
  end

  def available_entities_for(event)
    [event] + event.questionnaires.includes(:questions).flat_map do |questionnaire|
      [questionnaire] + questionnaire.questions
    end
  end
end
