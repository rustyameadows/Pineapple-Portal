module Documents
  class GeneratedController < ApplicationController
    before_action :set_event
    before_action :set_generated_document, only: %i[show update compile]

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

    def compile
      segments = DocumentSegment.where(document_logical_id: @document.logical_id).ordered.to_a

      if segments.empty?
        redirect_to builder_path, alert: "Add at least one segment before compiling."
        return
      end

      blockers = compile_blockers(segments)
      if blockers.any?
        redirect_to builder_path, alert: blockers.join("; ")
        return
      end

      page_numbers = ActiveModel::Type::Boolean.new.cast(params[:page_numbers])

      build = @document.builds.create!(
        build_id: SecureRandom.uuid,
        status: DocumentBuild::STATUSES[:pending],
        built_by_user: current_user
      )

      job_options = { page_numbers: page_numbers }
      Documents::Generated::CompileDocumentJob.perform_later(build.id, job_options)
      redirect_to builder_path, notice: "Compile queued. We'll notify you when the PDF is ready."
    rescue StandardError => e
      redirect_to builder_path, alert: "Unable to queue compile: #{e.message}"
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
      @latest_version = @compiled_versions.max_by(&:version)
      @available_pdf_documents = @event.documents.where(doc_kind: Document::DOC_KINDS[:uploaded]).order(:title)
      @available_html_views = DocumentSegment.html_view_options
      @available_timeline_views = timeline_view_options
      @builds = @document.builds.recent_first.to_a
      @active_build = @builds.find { |build| build.pending? || build.running? }
      @segment_warnings = segment_blockers_map(@segments)
    end

    def builder_path
      event_documents_generated_path(@event, @document.logical_id)
    end

    def compile_blockers(segments)
      segment_blockers_map(segments).values
    end

    def segment_blockers_map(segments)
      warnings = {}

      if segments.any?(&:pdf_asset?)
        pdf_segments = segments.select(&:pdf_asset?)
        attached_ids = pdf_segments.filter_map(&:pdf_document_id)
        documents_by_id = @event.documents.where(id: attached_ids).index_by(&:id)

        pdf_segments.each do |segment|
          document = documents_by_id[segment.pdf_document_id]
          if document.nil?
            warnings[segment.id] = "#{segment.display_title}: attach a PDF before compiling"
          elsif document.storage_uri.blank?
            warnings[segment.id] = "#{segment.display_title}: attached PDF is missing a stored file"
          end
        end
      end

      segments.each do |segment|
        next unless segment.html_view?

        if segment.html_view_config.blank?
          warnings[segment.id] = "#{segment.display_title}: select a branded section"
        end
      end

      warnings
    end

    def timeline_view_options
      calendar = @event.run_of_show_calendar
      return [] unless calendar

      calendar.event_calendar_views.order(:name).map { |view| [view.name, view.id.to_s] }
    end
  end
end
