module Documents
  class GeneratedController < ApplicationController
    before_action :set_event
    before_action :set_generated_document, only: %i[show update compile working_pdf]
    before_action :ensure_source_backed_document!, only: %i[show update compile working_pdf]

    def index
      @manifest_entries = build_manifest_entries
    end

    def library
      GeneratedPacketSource.ensure_canonical_sources_for_event!(@event)
      @packet_definitions = packet_definitions
      @canonical_sources = @event.generated_packet_sources.where(source_category: GeneratedPacketSource::CATEGORIES[:canonical]).order(:title)
      @page_sources = @event.generated_packet_sources.where(source_category: GeneratedPacketSource::CATEGORIES[:page]).order(updated_at: :desc, title: :asc)
      @uploaded_pdf_documents = uploaded_pdf_documents
      @source_usage_labels = source_usage_labels
      @upload_usage_labels = upload_usage_labels
    end

    def new
      @document = build_definition
      @templates = template_scope.order(:title)
    end

    def create
      @document = build_definition
      @document.assign_attributes(definition_params)

      if @document.save
        redirect_to event_documents_generated_path(@event, @document.logical_id), notice: "Packet created."
      else
        @templates = template_scope.order(:title)
        flash.now[:alert] = "Could not create packet. Please review the errors below."
        render :new, status: :unprocessable_content
      end
    end

    def show
      load_document_context
    end

    def update
      if @document.update(definition_params)
        redirect_to event_documents_generated_path(@event, @document.logical_id), notice: "Packet updated."
      else
        redirect_to event_documents_generated_path(@event, @document.logical_id), alert: @document.errors.full_messages.to_sentence
      end
    end

    def working_pdf
      if @document.packet_placements.none?
        render_working_placeholder("No packet pages yet. Add a canonical, page, or upload to start the live PDF.")
        return
      end

      result = Documents::Generated::WorkingCopyBuilder.new(definition_document: @document).call
      url = R2::Storage.new.presigned_download_url(key: result.storage_key)
      redirect_to url, allow_other_host: true
    rescue Documents::Generated::Compiler::CompileError => e
      render_working_placeholder(e.message)
    rescue StandardError => e
      render_working_placeholder("Unable to render the working PDF: #{e.message}")
    end

    def compile
      segments = current_segments

      if segments.empty?
        redirect_to builder_path, alert: "Add at least one page before creating a snapshot."
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
      redirect_to builder_path, notice: "Snapshot queued. We’ll keep the builder live while the saved version is generated."
    rescue StandardError => e
      redirect_to builder_path, alert: "Unable to queue snapshot: #{e.message}"
    end

    def add_default_packets
      created = Documents::Generated::DefaultPacketBuilder.new(event: @event, built_by_user: current_user).call
      message = if created.any?
                  "Added #{created.size} default packet#{'s' if created.size != 1}."
                else
                  "All default packets already exist."
                end

      redirect_to event_documents_generated_index_path(@event), notice: message
    rescue StandardError => e
      redirect_to event_documents_generated_index_path(@event), alert: "Unable to add default packets: #{e.message}"
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
        built_by_user: current_user,
        packet_schema_version: Document::PACKET_SCHEMA_VERSIONS[:source_backed]
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
      GeneratedPacketSource.ensure_canonical_sources_for_event!(@event)
      @segments = current_segments
      @versions = generated_scope.where(logical_id: @document.logical_id).order(version: :desc).to_a
      @compiled_versions = @versions.select { |record| record.storage_uri.present? }
      @latest_version = @compiled_versions.max_by(&:version)
      @available_pdf_documents = uploaded_pdf_documents
      @available_page_views = GeneratedPacketSource.page_view_options
      @available_timeline_views = timeline_view_options
      @available_canonical_sources = @event.generated_packet_sources.where(source_category: GeneratedPacketSource::CATEGORIES[:canonical]).order(:title)
      @available_page_sources = @event.generated_packet_sources.where(source_category: GeneratedPacketSource::CATEGORIES[:page]).order(updated_at: :desc, title: :asc)
      @packet_definitions = packet_definitions.reject { |definition| definition.logical_id == @document.logical_id }
      @source_usage_labels = source_usage_labels
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

    def current_segments
      if @document.packet_source_backed? || @document.packet_placements.exists?
        @document.packet_placements.includes(:source).ordered.to_a
      else
        @document.segments.ordered.to_a
      end
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

    def packet_definitions
      build_manifest_entries.map { |entry| entry[:definition] }
    end

    def source_usage_labels
      definitions_by_logical_id = packet_definitions.index_by(&:logical_id)
      placements = GeneratedPacketPlacement.where(document_logical_id: definitions_by_logical_id.keys)

      placements.group_by(&:generated_packet_source_id).transform_values do |source_placements|
        source_placements
          .map { |placement| definitions_by_logical_id[placement.document_logical_id]&.title }
          .compact
          .uniq
      end
    end

    def upload_usage_labels
      usage_by_logical_id = Hash.new { |hash, key| hash[key] = [] }
      definitions_by_logical_id = packet_definitions.index_by(&:logical_id)

      @event.generated_packet_sources.where(source_category: GeneratedPacketSource::CATEGORIES[:upload]).includes(:packet_placements).find_each do |source|
        source.packet_placements.each do |placement|
          title = definitions_by_logical_id[placement.document_logical_id]&.title
          next if title.blank?

          usage_by_logical_id[source.pdf_logical_id] << title
        end
      end

      usage_by_logical_id.transform_values(&:uniq)
    end

    def uploaded_pdf_documents
      @event.documents
            .where(doc_kind: Document::DOC_KINDS[:uploaded])
            .latest
            .where("content_type = ? OR content_type LIKE ?", "application/pdf", "application/%pdf%")
            .order(:title)
    end

    def ensure_source_backed_document!
      return if @document.packet_source_backed?

      Documents::Generated::LegacyPacketMigrator.new(document: @document).call
      @document.reload
    end

    def render_working_placeholder(message)
      @message = message
      render inline: <<~ERB, layout: false
        <section class="generated-template generated-template--text-page" style="padding: 2rem; font-family: Georgia, serif;">
          <p><%= ERB::Util.html_escape(@message) %></p>
        </section>
      ERB
    end
  end
end
