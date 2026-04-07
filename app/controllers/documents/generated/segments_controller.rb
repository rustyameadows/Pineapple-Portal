module Documents
  module Generated
    class SegmentsController < ApplicationController
      before_action :set_event
      before_action :set_document
      before_action :ensure_source_backed_document!
      before_action :set_placement, only: %i[update destroy preview cached_pdf duplicate]

      def create
        source = build_source_from_params(segment_params)
        placement = placements_scope.new(source: source)

        if source.errors.none? && placement.save
          enqueue_working_refresh_for_documents(@document)
          redirect_to builder_path, notice: "Packet page added."
        else
          message = source.errors.full_messages + placement.errors.full_messages
          redirect_to builder_path, alert: message.uniq.to_sentence
        end
      end

      def update
        assign_source_payload(@placement.source, segment_params)

        if @placement.source.errors.empty? && @placement.source.save
          enqueue_working_refresh_for_source(@placement.source)
          redirect_to builder_path, notice: "Packet page updated."
        else
          redirect_to builder_path, alert: @placement.source.errors.full_messages.to_sentence
        end
      end

      def destroy
        @placement.destroy
        resequence_placements!
        if placements_scope.exists?
          enqueue_working_refresh_for_documents(@document)
        else
          @document.clear_working_copy!
        end
        redirect_to builder_path, notice: "Packet page removed."
      end

      def duplicate
        source = duplicate_source(@placement.source)
        new_position = @placement.position + 1

        GeneratedPacketPlacement.transaction do
          placements_scope.where("position >= ?", new_position).update_all("position = position + 1")
          placements_scope.create!(source: source, position: new_position)
          resequence_placements!
        end
        enqueue_working_refresh_for_documents(@document)

        redirect_to builder_path, notice: "Page duplicated."
      end

      def reorder
        ordered_ids = extract_order_ids
        return head :unprocessable_entity if ordered_ids.empty?

        GeneratedPacketPlacement.transaction do
          temp_position = placements_scope.maximum(:position).to_i + ordered_ids.length + 5

          ordered_ids.each do |placement_id|
            placements_scope.where(id: placement_id).update_all(position: temp_position)
            temp_position += 1
          end

          ordered_ids.each_with_index do |placement_id, index|
            placements_scope.where(id: placement_id).update_all(position: index + 1)
          end

          resequence_placements!
        end
        enqueue_working_refresh_for_documents(@document)

        head :ok
      end

      def preview
        source = @placement.source

        if source.html_view?
          view_config = source.html_view_config
          if view_config
            @segment = source
            render template: view_config[:template], layout: "generated_preview"
          else
            head :not_found
          end
        elsif source.pdf_asset? && (document = find_pdf_document(source.pdf_document_id || source.pdf_logical_id))
          redirect_to download_event_document_path(@event, document)
        else
          head :not_found
        end
      end

      def cached_pdf
        source = @placement.source

        unless source.cached?
          redirect_to builder_path, alert: "Page has not been rendered yet."
          return
        end

        url = storage.presigned_download_url(source.cached_pdf_key)
        redirect_to url, allow_other_host: true
      rescue StandardError => e
        redirect_to builder_path, alert: "Unable to fetch cached PDF: #{e.message}"
      end

      private

      def set_event
        @event = Event.find(params[:event_id])
      end

      def set_document
        logical_id = params[:logical_id] || params[:generated_id] || params[:generated_logical_id]
        scope = @event.documents.where(doc_kind: Document::DOC_KINDS[:generated])
        @document = scope.find_by(logical_id: logical_id, storage_uri: nil)
        @document ||= scope.where(logical_id: logical_id).order(version: :asc).first
        raise ActiveRecord::RecordNotFound unless @document
      end

      def ensure_source_backed_document!
        return if @document.packet_source_backed?

        Documents::Generated::LegacyPacketMigrator.new(document: @document).call
        @document.reload
      end

      def set_placement
        @placement = placements_scope.find(params[:id])
      end

      def placements_scope
        GeneratedPacketPlacement.where(document_logical_id: @document.logical_id)
      end

      def build_source_from_params(attrs)
        existing_source = find_existing_source(attrs[:source_id])
        return existing_source if existing_source

        uploaded_document = build_uploaded_document(attrs)
        if uploaded_document == :invalid_upload
          return invalid_source_with_errors
        elsif uploaded_document.present?
          return GeneratedPacketSource.find_or_create_upload_source!(@event, uploaded_document, title: attrs[:title])
        end

        if (pdf_document = find_pdf_document(attrs[:pdf_document_id] || attrs[:document_id]))
          return GeneratedPacketSource.find_or_create_upload_source!(@event, pdf_document, title: attrs[:title])
        end

        build_page_source(attrs)
      end

      def build_uploaded_document(attrs)
        upload_attrs = file_upload_params(attrs)
        return if upload_attrs.blank?

        document = @event.documents.new(upload_attrs.merge(source: "staff_upload", doc_kind: Document::DOC_KINDS[:uploaded]))
        return document if document.save

        @invalid_source = @event.generated_packet_sources.new
        document.errors.full_messages.each { |message| @invalid_source.errors.add(:base, message) }
        :invalid_upload
      end

      def build_page_source(attrs)
        unless GeneratedPacketSource.page_view_keys.include?(attrs[:view_key].to_s)
          return @event.generated_packet_sources.new.tap do |source|
            source.errors.add(:base, "Choose a page type.")
          end
        end

        source = GeneratedPacketSource.build_page_source(
          event: @event,
          view_key: attrs[:view_key],
          title: attrs[:title],
          options: sanitize_html_view_options(attrs[:view_key], normalize_options(attrs[:options]))
        )

        source.save
        source
      end

      def assign_source_payload(source, attrs)
        source.title = attrs[:title] if attrs.key?(:title) && attrs[:title].present?

        case source.kind
        when GeneratedPacketSource::KINDS[:pdf_asset]
          assign_pdf_payload(source, attrs)
        when GeneratedPacketSource::KINDS[:html_view]
          assign_html_payload(source, attrs)
        end
      end

      def assign_pdf_payload(source, attrs)
        pdf_document = find_pdf_document(attrs[:pdf_document_id] || attrs[:document_id])
        if pdf_document
          source.assign_pdf_document(pdf_document)
        else
          source.errors.add(:base, "Select a PDF to attach.")
        end
      end

      def assign_html_payload(source, attrs)
        view_key = attrs[:view_key].presence || source.html_view_key
        unless GeneratedPacketSource.html_view?(view_key)
          source.errors.add(:base, "Choose a page type.")
          return
        end

        raw_options = attrs.key?(:options) ? normalize_options(attrs[:options]) : source.html_options
        options = sanitize_html_view_options(view_key, raw_options)
        options = apply_default_html_view_options(view_key, options)
        source.assign_html_view(view_key, options: options)
      end

      def duplicate_source(source)
        @event.generated_packet_sources.create!(
          source_category: source.canonical? ? GeneratedPacketSource::CATEGORIES[:page] : source.source_category,
          kind: source.kind,
          title: source.title,
          source_ref: source.source_ref.deep_dup,
          spec: source.spec.deep_dup
        )
      end

      def find_existing_source(value)
        return if value.blank?

        @event.generated_packet_sources.find_by(id: value)
      end

      def invalid_source_with_errors
        @invalid_source || @event.generated_packet_sources.new.tap do |source|
          source.errors.add(:base, "Unable to create packet page.")
        end
      end

      def find_pdf_document(value)
        return if value.blank?

        if value.to_s =~ /\A\d+\z/
          @event.documents.where(doc_kind: Document::DOC_KINDS[:uploaded]).find_by(id: value)
        else
          @event.documents.where(doc_kind: Document::DOC_KINDS[:uploaded]).latest.find_by(logical_id: value)
        end
      end

      def segment_params
        params.require(:segment).permit(
          :title,
          :source_id,
          :pdf_document_id,
          :document_id,
          :view_key,
          options: {},
          file_upload: %i[title storage_uri checksum size_bytes content_type logical_id]
        )
      end

      def file_upload_params(attrs)
        upload = attrs[:file_upload]
        upload = upload.to_h if upload.respond_to?(:to_h)
        upload = upload&.stringify_keys
        return if upload.blank? || upload["storage_uri"].blank?

        {
          title: upload["title"].presence || File.basename(upload["storage_uri"].to_s),
          storage_uri: upload["storage_uri"],
          checksum: upload["checksum"],
          size_bytes: upload["size_bytes"].to_i,
          content_type: upload["content_type"].presence || "application/pdf",
          logical_id: upload["logical_id"].presence || SecureRandom.uuid
        }
      end

      def builder_path
        event_documents_generated_path(@event, @document.logical_id)
      end

      def storage
        @storage ||= Documents::Generated::R2Storage.new
      end

      def extract_order_ids
        raw_ids = params[:segment_ids]
        raw_ids = params[:order] if raw_ids.blank?
        Array(raw_ids).map(&:to_i).reject(&:zero?)
      end

      def resequence_placements!
        placements_scope.ordered.each_with_index do |placement, index|
          next if placement.position == index + 1

          placement.update_column(:position, index + 1)
        end
      end

      def normalize_options(options)
        options = options.to_unsafe_h if options.respond_to?(:to_unsafe_h)
        options = options.to_h if options.respond_to?(:to_h) && !options.is_a?(Hash)
        options.presence || {}
      end

      def sanitize_html_view_options(view_key, options)
        case view_key.to_s
        when DocumentSegment::TIMELINE_VIEW_KEY
          sanitize_timeline_options(options)
        when DocumentSegment::RUN_OF_SHOW_VIEW_KEY
          sanitize_run_of_show_options(options)
        when DocumentSegment::TEXT_PAGE_VIEW_KEY
          sanitize_markdown_body_options(options)
        when DocumentSegment::EVENT_OVERVIEW_VIEW_KEY,
             DocumentSegment::VENDOR_CONTACTS_VIEW_KEY,
             DocumentSegment::WEDDING_PARTY_REFERENCE_VIEW_KEY
          {}
        else
          options
        end
      end

      def apply_default_html_view_options(view_key, options)
        options
      end

      def sanitize_timeline_options(options)
        source = options.to_h.stringify_keys
        sanitized = {}

        sanitized["view_ref"] = sanitize_timeline_view_ref(source["view_ref"])
        sanitized["show_location"] = boolean_option(source.fetch("show_location", true), default: true)
        sanitized["show_vendor"] = boolean_option(source.fetch("show_vendor", true), default: true)
        sanitized["show_team_members"] = boolean_option(source.fetch("show_team_members", true), default: true)

        sanitized
      end

      def sanitize_run_of_show_options(options)
        source = options.to_h.stringify_keys
        {
          "show_location" => boolean_option(source.fetch("show_location", true), default: true),
          "show_vendor" => boolean_option(source.fetch("show_vendor", true), default: true),
          "show_team_members" => boolean_option(source.fetch("show_team_members", true), default: true)
        }
      end

      def sanitize_markdown_body_options(options)
        source = options.to_h.stringify_keys
        body = source["body_markdown"].to_s
        normalized_body = body.gsub(/\r\n?/, "\n").delete("\u0000")
        { "body_markdown" => normalized_body.first(20_000) }
      end

      def sanitize_timeline_view_ref(value)
        allowed_refs = timeline_view_refs
        fallback = allowed_refs.first

        candidate = value.to_s
        candidate = fallback if candidate.blank?
        return candidate if candidate.present? && allowed_refs.include?(candidate)

        fallback
      end

      def boolean_option(value, default: false)
        return default if value.nil?

        ActiveModel::Type::Boolean.new.cast(value)
      end

      def timeline_view_refs
        return @timeline_view_refs if defined?(@timeline_view_refs)

        calendar = @event.run_of_show_calendar
        @timeline_view_refs = if calendar
                                calendar.event_calendar_views.order(:name).pluck(:id).map(&:to_s)
                              else
                                []
                              end
      end

      def enqueue_working_refresh_for_documents(*documents)
        Array(documents).flatten.compact.uniq.each do |document|
          Documents::Generated::WorkingCopyRefresh.enqueue(document)
        end
      end

      def enqueue_working_refresh_for_source(source)
        document_logical_ids = source.packet_placements.pluck(:document_logical_id)
        documents = @event.documents.generated.where(logical_id: document_logical_ids, storage_uri: nil)
        enqueue_working_refresh_for_documents(documents)
      end
    end
  end
end
