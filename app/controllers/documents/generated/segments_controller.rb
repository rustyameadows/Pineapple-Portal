module Documents
  module Generated
    class SegmentsController < ApplicationController
      before_action :set_event
      before_action :set_document
      before_action :set_segment, only: %i[render_pdf update destroy preview cached_pdf]

      def create
        @segment = segments_scope.new
        assign_segment_payload(@segment, segment_params)

        if @segment.errors.empty? && @segment.save
          DocumentSegment.resequence!(@document.logical_id)
          redirect_to builder_path, notice: "Segment added."
        else
          redirect_to builder_path, alert: @segment.errors.full_messages.to_sentence
        end
      end

      def update
        assign_segment_payload(@segment, segment_params)

        if @segment.errors.empty? && @segment.save
          redirect_to builder_path, notice: "Segment updated."
        else
          redirect_to builder_path, alert: @segment.errors.full_messages.to_sentence
        end
      end

      def destroy
        @segment.destroy
        DocumentSegment.resequence!(@document.logical_id)
        redirect_to builder_path, notice: "Segment removed."
      end

      def render_pdf
        RenderSegmentJob.perform_later(@segment.id)
        redirect_to builder_path, notice: "Segment render queued."
      rescue StandardError => e
        redirect_to builder_path, alert: "Unable to render segment: #{e.message}"
      end

      def reorder
        ordered_ids = extract_order_ids

        if ordered_ids.empty?
          head :unprocessable_entity
          return
        end

        DocumentSegment.transaction do
          temp_position = segments_scope.maximum(:position).to_i + ordered_ids.length + 5

          ordered_ids.each do |segment_id|
            segments_scope.where(id: segment_id).update_all(position: temp_position)
            temp_position += 1
          end

          ordered_ids.each_with_index do |segment_id, index|
            segments_scope.where(id: segment_id).update_all(position: index + 1)
          end

          DocumentSegment.resequence!(@document.logical_id)
        end

        head :ok
      end

      def preview
        if @segment.html_view?
          view_config = @segment.html_view_config
          if view_config
            render template: view_config[:template], layout: "generated_preview"
          else
            head :not_found
          end
        elsif @segment.pdf_asset? && (document = find_pdf_document(@segment.pdf_document_id))
          redirect_to download_event_document_path(@event, document)
        else
          head :not_found
        end
      end

      def cached_pdf
        unless @segment.cached?
          redirect_to builder_path, alert: "Segment has not been rendered yet."
          return
        end

        url = storage.presigned_download_url(@segment.cached_pdf_key)
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
        @document = scope.find_by(logical_id: logical_id)
        raise ActiveRecord::RecordNotFound unless @document
      end

      def set_segment
        @segment = segments_scope.find(params[:id])
      end

      def segments_scope
        DocumentSegment.where(document_logical_id: @document.logical_id)
      end

      def assign_segment_payload(segment, attrs)
        segment.title = attrs[:title] if attrs.key?(:title)

        if segment.new_record?
          segment.kind = attrs[:kind]
          segment.position = segments_scope.maximum(:position).to_i + 1
        end

        unless DocumentSegment::KINDS.value?(segment.kind)
          segment.errors.add(:base, "Choose a segment type.")
          return
        end

        case segment.kind
        when DocumentSegment::KINDS[:pdf_asset]
          assign_pdf_payload(segment, attrs)
        when DocumentSegment::KINDS[:html_view]
          assign_html_payload(segment, attrs)
        end
      end

      def assign_pdf_payload(segment, attrs)
        pdf_id = attrs[:pdf_document_id].presence || attrs[:document_id]
        document = find_pdf_document(pdf_id)

        if document
          segment.assign_pdf_document(document)
        else
          segment.errors.add(:base, "Select a document to attach.")
        end
      end

      def assign_html_payload(segment, attrs)
        view_key = attrs[:view_key].presence || attrs[:html_view_key]

        unless DocumentSegment.html_view?(view_key)
          segment.errors.add(:base, "Choose a branded section.")
          return
        end

        options = attrs[:options]
        options = options.to_unsafe_h if options.respond_to?(:to_unsafe_h)
        options = options.to_h if options.respond_to?(:to_h) && !options.is_a?(Hash)
        options = options.presence || {}
        options = sanitize_html_view_options(view_key, options)
        segment.assign_html_view(view_key, options: options)
      end

      def find_pdf_document(value)
        return if value.blank?

        if value.to_s =~ /\A\d+\z/
          @event.documents.where(doc_kind: Document::DOC_KINDS[:uploaded]).find_by(id: value)
        else
          @event.documents.where(doc_kind: Document::DOC_KINDS[:uploaded]).find_by(logical_id: value)
        end
      end

      def segment_params
        params.require(:segment).permit(:title, :kind, :pdf_document_id, :document_id, :view_key, :html_view_key, options: {})
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

      def sanitize_html_view_options(view_key, options)
        case view_key.to_s
        when DocumentSegment::TIMELINE_VIEW_KEY
          sanitize_timeline_options(options)
        when DocumentSegment::RUN_OF_SHOW_VIEW_KEY
          sanitize_run_of_show_options(options)
        else
          options
        end
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
    end
  end
end
