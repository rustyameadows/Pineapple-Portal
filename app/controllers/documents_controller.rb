class DocumentsController < ApplicationController
  before_action :set_event
  before_action :set_document, only: %i[show edit update destroy download]
  before_action :load_document_groups, only: %i[index packets staff_uploads client_uploads]

  def index
    @documents = @event.documents.latest.order(updated_at: :desc, title: :asc)
  end

  def packets
    render_grouped_documents(:packet)
  end

  def staff_uploads
    render_grouped_documents(:staff_upload)
  end

  def client_uploads
    render_grouped_documents(:client_upload)
  end

  def show
    @attachments = @document.attachments.includes(:entity).order(:context, :position)
    @available_entities = available_entities_for(@event)
    @versions = versions_for(@document.logical_id)
  end

  def new
    @document = @event.documents.new
    @reference_document = reference_document_for(params[:logical_id])
    if @reference_document
      @document.logical_id = @reference_document.logical_id
    elsif params[:logical_id].present?
      @document.logical_id = params[:logical_id]
    end
    @existing_versions = versions_for(@document.logical_id)
  end

  def create
    @document = @event.documents.new(document_params)

    if @document.save
      redirect_to event_document_path(@event, @document), notice: "Document saved."
    else
      @reference_document = reference_document_for(@document.logical_id)
      @existing_versions = versions_for(@document.logical_id)
      render :new, status: :unprocessable_content
    end
  end

  def edit
    @existing_versions = versions_for(@document.logical_id)
  end

  def update
    if @document.update(edit_document_params)
      redirect_to event_document_path(@event, @document), notice: "Document updated."
    else
      @existing_versions = versions_for(@document.logical_id)
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
    params.require(:document).permit(:title, :storage_uri, :checksum, :size_bytes, :content_type, :logical_id, :client_visible, :source)
  end

  def edit_document_params
    params.require(:document).permit(:title, :content_type, :client_visible, :source)
  end

  def available_entities_for(event)
    [event] + event.questionnaires.includes(:questions).flat_map do |questionnaire|
      [questionnaire] + questionnaire.questions
    end
  end

  def render_grouped_documents(source_key)
    @source_key = source_key.to_s
    @label = document_source_label(@source_key)
    @documents = @event.documents.where(source: @source_key).order(title: :asc, version: :desc)
    load_document_groups
    render :group
  end

  def load_document_groups
    @document_groups = build_document_groups
  end

  def build_document_groups
    Document.sources.keys.map do |key|
      scope = @event.documents.where(source: key)
      {
        key: key,
        label: document_source_label(key),
        documents_count: scope.count,
        latest_count: scope.where(is_latest: true).count
      }
    end
  end

  def document_source_label(key)
    DocumentsHelper::SOURCE_LABELS[key.to_s] || key.to_s.humanize
  end

  def versions_for(logical_id)
    return Document.none if logical_id.blank?

    @event.documents.where(logical_id: logical_id).order(version: :desc)
  end

  def reference_document_for(logical_id)
    versions_for(logical_id).first
  end
end
