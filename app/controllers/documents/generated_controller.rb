module Documents
  class GeneratedController < ApplicationController
    before_action :set_event
    before_action :set_generated_document, only: %i[show update]

    def index
      @manifest_entries = build_manifest_entries
      @document = build_definition
      @templates = template_scope.order(:title)
    end

    def new
      @document = build_definition
    end

    def create
      @document = build_definition
      @document.assign_attributes(definition_params)

      if @document.save
        redirect_to event_documents_generated_path(@event, @document.logical_id), notice: "Generated document created."
      else
        @manifest_entries = build_manifest_entries
        @templates = template_scope.order(:title)
        flash.now[:alert] = "Could not create generated document. Please review the errors below."
        render :index, status: :unprocessable_content
      end
    end

    def show
      load_document_context
    end

    def update
      if @document.update(definition_params)
        redirect_to event_documents_generated_path(@event, @document.logical_id), notice: "Document updated."
      else
        redirect_to event_documents_generated_path(@event, @document.logical_id), alert: @document.errors.full_messages.to_sentence
      end
    end

    private

    def set_event
      @event = Event.find(params[:event_id])
    end

    def generated_scope
      @generated_scope ||= @event.documents.where(doc_kind: Document::DOC_KINDS[:generated])
    end

    def build_manifest_entries
      grouped = generated_scope.where(is_template: false)
                                .order(:logical_id, version: :asc)
                                .group_by(&:logical_id)

      grouped.map do |logical_id, records|
        definition = records.find { |record| record.definition_placeholder? } || records.first
        latest = records.find(&:is_latest?)

        {
          logical_id: logical_id,
          definition: definition,
          latest: latest,
          versions: records.sort_by(&:version).reverse
        }
      end.sort_by { |entry| entry[:definition]&.title.to_s.downcase }
    end

    def build_definition
      attrs = {
        doc_kind: Document::DOC_KINDS[:generated],
        client_visible: false,
        is_template: false,
        is_latest: false,
        built_by_user: current_user
      }

      @event.documents.new(attrs)
    end

    def template_scope
      generated_scope.where(is_template: true)
    end

    def set_generated_document
      logical_id = params[:logical_id] || params[:generated_id] || params[:generated_logical_id]
      scope = generated_scope.where(logical_id: logical_id)
      @document = scope.find_by(storage_uri: nil)
      @document ||= scope.order(version: :asc).first

      raise ActiveRecord::RecordNotFound unless @document
    end

    def definition_params
      params.fetch(:document, {}).permit(:title, :client_visible)
    end

    def load_document_context
      @segments = DocumentSegment.where(document_logical_id: @document.logical_id).ordered
      @versions = generated_scope.where(logical_id: @document.logical_id).order(version: :desc).to_a
      @compiled_versions = @versions.select { |record| record.storage_uri.present? }
      @latest_version = @versions.find { |record| record.is_latest? }
      @available_pdf_documents = @event.documents.where(doc_kind: Document::DOC_KINDS[:uploaded]).order(:title)
      @available_html_views = DocumentSegment.html_view_options
    end
  end
end
