module Documents
  class GeneratedController < ApplicationController
    before_action :set_event
    before_action :set_generated_document, only: %i[show edit update destroy compile rebuild_live working_pdf working_status]
    before_action :ensure_source_backed_document!, only: %i[show edit update compile rebuild_live working_pdf working_status]

    def index
      @manifest_entries = build_manifest_entries
    end

    def library
      GeneratedPacketSource.ensure_canonical_sources_for_event!(@event)
      @packet_definitions = packet_definitions
      @group_sources = @event.generated_packet_sources.group_sources.order(:title)
      @canonical_sources = @event.generated_packet_sources.where(source_category: GeneratedPacketSource::CATEGORIES[:canonical]).order(:title)
      @page_sources = @event.generated_packet_sources.where(source_category: GeneratedPacketSource::CATEGORIES[:page]).order(updated_at: :desc, title: :asc)
      @uploaded_pdf_documents = uploaded_pdf_documents
      usage_map = usage_map_result
      @source_usage_labels = usage_map.source_packets
      @upload_usage_labels = usage_map.upload_packets
      @group_usage_labels = usage_map.group_packets
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
      if @document.group_container?
        redirect_to edit_event_documents_generated_path(@event, @document.logical_id)
        return
      end

      load_document_context
      @working_copy = current_working_copy_access
    end

    def edit
      load_document_context
      @packet_pages_count = @segments.count
      @compiled_versions_count = @compiled_versions.count
    end

    def update
      if @document.update(definition_params)
        sync_group_sources! if @document.group_container?
        redirect_to(@document.group_container? ? edit_event_documents_generated_path(@event, @document.logical_id) : event_documents_generated_path(@event, @document.logical_id),
                    notice: "#{@document.group_container? ? 'Group' : 'Packet'} updated.")
      else
        redirect_to edit_event_documents_generated_path(@event, @document.logical_id), alert: @document.errors.full_messages.to_sentence
      end
    end

    def destroy
      title = @document.title
      packets_to_refresh = @document.group_container? ? packet_consumer_resolver.for_container(@document).to_a : []

      Document.transaction do
        destroy_group_sources! if @document.group_container?
        generated_scope.where(logical_id: @document.logical_id).to_a.each(&:destroy!)
      end

      enqueue_working_refresh_for_documents(packets_to_refresh) if packets_to_refresh.any?

      redirect_to(@document.group_container? ? library_event_documents_generated_index_path(@event) : event_documents_generated_index_path(@event), notice: "#{title} deleted.")
    rescue StandardError => e
      redirect_to edit_event_documents_generated_path(@event, @document.logical_id), alert: "Unable to delete packet: #{e.message}"
    end

    def working_pdf
      if @document.group_container?
        redirect_to edit_event_documents_generated_path(@event, @document.logical_id), alert: "Groups do not have live PDFs."
        return
      end

      access = current_working_copy_access

      if access.empty?
        disable_response_cache!
        render_working_placeholder("No packet pages yet. Add a canonical, page, or upload to start the live PDF.")
        return
      end

      if access.working_available
        disable_response_cache!
        pdf_io = R2::Storage.new.download(access.working_storage_uri)
        raise "Live PDF is missing from storage." unless pdf_io

        send_data pdf_io.read, type: "application/pdf", disposition: "inline"
        return
      end

      disable_response_cache!
      message = if access.failed?
                  access.refresh_error.presence || "Unable to refresh the live PDF right now."
                else
                  "This packet is preparing its live PDF. Leave the page open and it will appear automatically."
                end

      render_working_placeholder(message)
    rescue StandardError => e
      disable_response_cache!
      render_working_placeholder("Unable to render the working PDF: #{e.message}")
    end

    def working_status
      if @document.group_container?
        render json: Documents::Generated::BuildStatusPresenter.new(
          build: nil,
          status: "missing",
          working_available: false,
          viewer_token: "missing"
        ).as_json
        return
      end

      access = current_working_copy_access

      disable_response_cache!

      render json: Documents::Generated::BuildStatusPresenter.new(
        build: access.build,
        status: access.status,
        working_available: access.working_available,
        rendered_at: access.rendered_at,
        refresh_error: access.refresh_error,
        viewer_token: access.viewer_token,
        viewer_path: (pdf_viewer_url(canonical_working_pdf_path(access.viewer_token)) if access.working_available)
      ).as_json
    rescue StandardError => e
      disable_response_cache!

      render json: Documents::Generated::BuildStatusPresenter.new(
        build: @document.current_working_progress_build,
        status: "failed",
        working_available: @document.working_available?,
        rendered_at: @document.working_rendered_at,
        refresh_error: e.message,
        viewer_token: @document.working_viewer_token,
        viewer_path: (pdf_viewer_url(canonical_working_pdf_path(@document.working_viewer_token)) if @document.working_available?)
      ).as_json
    end

    def rebuild_live
      if @document.group_container?
        redirect_to edit_event_documents_generated_path(@event, @document.logical_id), alert: "Groups do not have live PDFs."
        return
      end

      segments = current_segments

      if segments.empty?
        redirect_to safe_return_to(fallback: builder_path), alert: "Add at least one page before rebuilding the live PDF."
        return
      end

      blockers = compile_blockers(segments)
      if blockers.any?
        redirect_to safe_return_to(fallback: builder_path), alert: blockers.join("; ")
        return
      end

      Documents::Generated::ForceLiveRebuild.new(definition_document: @document).call
      redirect_to safe_return_to(fallback: builder_path), notice: "Live PDF rebuild queued."
    rescue StandardError => e
      redirect_to safe_return_to(fallback: builder_path), alert: "Unable to rebuild live PDF: #{e.message}"
    end

    def compile
      if @document.group_container?
        redirect_to edit_event_documents_generated_path(@event, @document.logical_id), alert: "Groups do not create snapshots."
        return
      end

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

      page_numbers = if params.key?(:page_numbers)
                       ActiveModel::Type::Boolean.new.cast(params[:page_numbers])
                     else
                       true
                     end

      active_build = @document.snapshot_builds.in_progress.recent_first.first
      if active_build.present?
        set_snapshot_build_flash(active_build)
        redirect_to builder_path
        return
      end

      build = @document.builds.create!(
        build_id: SecureRandom.uuid,
        status: DocumentBuild::STATUSES[:pending],
        build_kind: DocumentBuild::BUILD_KINDS[:snapshot],
        page_numbers: page_numbers,
        built_by_user: current_user
      )
      build.report_progress!(stage: :queued)

      Documents::Generated::RunDocumentBuildJob.perform_later(build.id)
      set_snapshot_build_flash(build, message: "Snapshot queued")
      redirect_to builder_path
    rescue StandardError => e
      redirect_to builder_path, alert: "Unable to queue snapshot: #{e.message}"
    end

    def add_default_packets
      result = Documents::Generated::DefaultPacketBuilder.new(event: @event, built_by_user: current_user).call
      result.packets.each { |packet| Documents::Generated::WorkingCopyRefresh.enqueue(packet) }

      redirect_to event_documents_generated_index_path(@event), notice: result.summary_message
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
      grouped = generated_scope.packet_containers.where(is_template: false)
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
        packet_schema_version: Document::PACKET_SCHEMA_VERSIONS[:source_backed],
        packet_container_kind: Document::PACKET_CONTAINER_KINDS[:packet]
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
      allowed = [:title]
      allowed << :client_visible unless @document&.group_container?
      params.fetch(:document, {}).permit(*allowed)
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
      @available_wedding_party_timeline_tags = wedding_party_timeline_tag_options
      @available_canonical_sources = @event.generated_packet_sources.where(source_category: GeneratedPacketSource::CATEGORIES[:canonical]).order(:title)
      @available_page_sources = @event.generated_packet_sources.where(source_category: GeneratedPacketSource::CATEGORIES[:page]).order(updated_at: :desc, title: :asc)
      @available_group_sources = @event.generated_packet_sources.group_sources.order(:title)
      @packet_definitions = packet_definitions.reject { |definition| definition.logical_id == @document.logical_id }
      usage_map = usage_map_result
      @source_usage_labels = usage_map.source_packets
      @upload_usage_labels = usage_map.upload_packets
      @group_usage_labels = usage_map.group_packets
      @builds = @document.snapshot_builds.recent_first.to_a
      @active_build = @builds.find { |build| build.pending? || build.running? }
      @segment_warnings = segment_blockers_map(@segments)
    end

    def builder_path
      @document.group_container? ? edit_event_documents_generated_path(@event, @document.logical_id) : event_documents_generated_path(@event, @document.logical_id)
    end

    def set_snapshot_build_flash(build, message: nil)
      flash[:snapshot_build_id] = build.id
      flash[:snapshot_build_message] = message.presence || build.display_progress_message
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
      leaf_entries = if @document.packet_source_backed? || @document.packet_placements.exists?
                       Documents::Generated::ContainerEntries.new(definition_document: @document).call
                     else
                       segments
                     end

      pdf_entries = leaf_entries.select { |entry| source_for_warning(entry).pdf_asset? }
      attached_ids = pdf_entries.filter_map { |entry| source_for_warning(entry).pdf_document_id }
      documents_by_id = @event.documents.where(id: attached_ids).index_by(&:id)

      pdf_entries.each do |entry|
        source = source_for_warning(entry)
        owner = warning_owner_for(entry)
        document = documents_by_id[source.pdf_document_id]

        if document.nil?
          warnings[owner.id] = "#{owner.display_title}: attach a PDF before compiling"
        elsif document.storage_uri.blank?
          warnings[owner.id] = "#{owner.display_title}: attached PDF is missing a stored file"
        end
      end

      leaf_entries.each do |entry|
        source = source_for_warning(entry)
        owner = warning_owner_for(entry)

        if source.group?
          warnings[owner.id] = "#{owner.display_title}: groups cannot contain other groups"
          next
        end

        next unless source.html_view?

        if source.html_view_config.blank?
          warnings[owner.id] = "#{owner.display_title}: select a branded section"
        end
      end

      segments.select { |segment| segment.respond_to?(:group?) && segment.group? }.each do |segment|
        if segment.group_document.nil?
          warnings[segment.id] = "#{segment.display_title}: select a valid group"
        elsif segment.group_document.packet_placements.none?
          warnings[segment.id] = "#{segment.display_title}: add at least one group page"
        end
      end

      warnings
    end

    def wedding_party_timeline_tag_options
      calendar = @event.run_of_show_calendar
      return [] unless calendar

      calendar.event_calendar_tags.includes(:event_key_person_group).order(:position, :name).map do |tag|
        label = if tag.event_key_person_group.present?
                  "#{tag.event_key_person_group.name} (#{tag.name})"
                else
                  tag.name
                end

        [label, tag.id]
      end
    end

    def timeline_view_options
      calendar = @event.run_of_show_calendar
      return [] unless calendar

      calendar.event_calendar_views.order(:name).map { |view| [view.name, view.id.to_s] }
    end

    def packet_definitions
      build_manifest_entries.map { |entry| entry[:definition] }
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

    def current_working_copy_access
      @current_working_copy_access ||= Documents::Generated::WorkingCopyAccess.new(
        definition_document: @document
      ).call
    end

    def usage_map_result
      @usage_map_result ||= Documents::Generated::PacketUsageMap.new(event: @event).call
    end

    def packet_consumer_resolver
      @packet_consumer_resolver ||= Documents::Generated::PacketConsumerResolver.new(event: @event)
    end

    def enqueue_working_refresh_for_documents(*documents)
      Array(documents).flatten.compact.uniq.each do |document|
        Documents::Generated::WorkingCopyRefresh.enqueue(document)
      end
    end

    def source_for_warning(entry)
      entry.respond_to?(:source) ? entry.source : entry
    end

    def warning_owner_for(entry)
      entry.respond_to?(:top_level_placement) && entry.top_level_placement.present? ? entry.top_level_placement : entry
    end

    def destroy_group_sources!
      @event.generated_packet_sources.group_sources.where("source_ref ->> 'logical_id' = ?", @document.logical_id).find_each(&:destroy!)
    end

    def sync_group_sources!
      @event.generated_packet_sources.group_sources.where("source_ref ->> 'logical_id' = ?", @document.logical_id).find_each do |source|
        source.assign_group_document(@document)
        source.save! if source.changed?
      end
    end

    def render_working_placeholder(message)
      @message = message
      render inline: <<~ERB, layout: false
        <section class="generated-template generated-template--text-page" style="padding: 2rem; font-family: Georgia, serif;">
          <p><%= ERB::Util.html_escape(@message) %></p>
        </section>
      ERB
    end

    def canonical_working_pdf_path(viewer_token)
      working_pdf_event_documents_generated_path(@event, @document.logical_id, v: viewer_token)
    end

    def disable_response_cache!
      response.headers["Cache-Control"] = "no-store, no-cache, must-revalidate, max-age=0"
      response.headers["Pragma"] = "no-cache"
      response.headers["Expires"] = "0"
    end

    def pdf_viewer_url(url)
      "#{url}#view=Fit"
    end
  end
end
