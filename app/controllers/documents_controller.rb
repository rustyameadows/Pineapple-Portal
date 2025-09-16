class DocumentsController < ApplicationController
  before_action :set_event, only: %i[index new create]
  before_action :set_document, only: %i[show edit update destroy]

  def index
    @documents = @event.documents.order(:title, :version)
  end

  def show
    @attachments = @document.attachments.includes(:entity).order(:context, :position)
    @available_entities = available_entities_for(@document.event)
  end

  def new
    @document = @event.documents.new
    @document.logical_id = params[:logical_id] if params[:logical_id].present?
  end

  def create
    @document = @event.documents.new(document_params)

    if @document.save
      redirect_to document_path(@document), notice: "Document saved."
    else
      render :new, status: :unprocessable_content
    end
  end

  def edit; end

  def update
    if @document.update(edit_document_params)
      redirect_to @document, notice: "Document updated."
    else
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    event = @document.event
    @document.destroy
    redirect_to event_documents_path(event), notice: "Document deleted."
  end

  private

  def set_event
    @event = Event.find(params[:event_id])
  end

  def set_document
    @document = Document.find(params[:id])
  end

  def document_params
    params.require(:document).permit(:title, :storage_uri, :checksum, :size_bytes, :content_type, :logical_id)
  end

  def edit_document_params
    params.require(:document).permit(:title, :content_type)
  end

  def available_entities_for(event)
    [event] + event.questionnaires.includes(:questions).flat_map do |questionnaire|
      [questionnaire] + questionnaire.questions
    end
  end
end
