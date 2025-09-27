require "grover"
require "pdf-reader"
require "stringio"

module Documents
  module Generated
    class SegmentRenderer
      Result = Struct.new(:render_hash, :storage_key, :page_count, :file_size, :generated_at, :error, keyword_init: true)

      GROVER_DEFAULTS = {
        format: "A4",
        margin: { top: "0.5in", bottom: "0.5in", left: "0.5in", right: "0.5in" },
        print_background: true
      }.freeze

      def initialize(segment, storage: default_storage)
        @segment = segment
        @storage = storage
      end

      def call
        hash = SegmentHasher.call(segment)

        if segment.cached? && !segment.cache_stale?(hash)
          return Result.new(
            render_hash: segment.render_hash,
            storage_key: segment.cached_pdf_key,
            page_count: segment.cached_page_count,
            file_size: segment.cached_file_size,
            generated_at: segment.cached_pdf_generated_at
          )
        end

        case segment.kind
        when DocumentSegment::KINDS[:pdf_asset]
          render_pdf_asset(hash)
        when DocumentSegment::KINDS[:html_view]
          render_html_view(hash)
        else
          Result.new(error: "Unsupported segment kind: #{segment.kind}")
        end
      rescue StandardError => e
        Rails.logger.error("[SegmentRenderer] #{e.class}: #{e.message}\n#{e.backtrace.take(10).join("\n")}")
        Result.new(error: e.message)
      end

      private

      attr_reader :segment, :storage

      def render_pdf_asset(hash)
        source = find_source_document
        return Result.new(error: "Attached document missing") unless source&.storage_uri.present?

        pdf_data = download_source_pdf(source)
        return Result.new(error: "Unable to download source PDF") if pdf_data.blank?

        page_count = count_pdf_pages(pdf_data)
        storage_key = storage.upload_segment(hash, pdf_data)

        Result.new(
          render_hash: hash,
          storage_key: storage_key,
          page_count: page_count,
          file_size: pdf_data.bytesize,
          generated_at: Time.current
        )
      end

      def render_html_view(hash)
        config = segment.html_view_config
        return Result.new(error: "Unknown branded section") unless config

        html = render_template(config[:template])
        pdf_data = Grover.new(html, **grover_options).to_pdf
        page_count = count_pdf_pages(pdf_data)
        storage_key = storage.upload_segment(hash, pdf_data)

        Result.new(
          render_hash: hash,
          storage_key: storage_key,
          page_count: page_count,
          file_size: pdf_data.bytesize,
          generated_at: Time.current
        )
      end

      def render_template(template)
        ApplicationController.render(
          template: template,
          layout: false,
          assigns: {
            event: segment.document.event,
            segment: segment
          }
        )
      end

      def grover_options
        GROVER_DEFAULTS
      end

      def find_source_document
        return unless segment.pdf_document_id

        segment.document.event.documents.find_by(id: segment.pdf_document_id)
      end

      def download_source_pdf(document)
        storage.download(document.storage_uri)
      end

      def count_pdf_pages(pdf_data)
        reader = PDF::Reader.new(StringIO.new(pdf_data))
        reader.page_count
      rescue PDF::Reader::MalformedPDFError, PDF::Reader::UnsupportedFeatureError
        nil
      end

      def default_storage
        R2Storage.new
end
  end
end
end
