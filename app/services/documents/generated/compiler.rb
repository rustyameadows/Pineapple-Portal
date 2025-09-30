require "combine_pdf"
require "digest"

module Documents
  module Generated
    class Compiler
      Result = Struct.new(
        :compiled_document,
        :manifest_hash,
        :page_count,
        :file_size,
        :checksum_md5,
        :checksum_sha256,
        keyword_init: true
      )

      def initialize(definition_document:, build:, built_by_user: nil, segment_storage: R2Storage.new, document_storage: R2::Storage.new, page_numbers: false)
        @definition_document = definition_document
        @build = build
        @built_by_user = built_by_user
        @segment_storage = segment_storage
        @document_storage = document_storage
        @page_numbers = !!page_numbers
      end

      def call
        check_cancelled!
        segments = definition_document.segments.ordered.to_a
        raise CompileError, "No segments configured" if segments.empty?

        rendered_segments = segments.map do |segment|
          check_cancelled!
          ensure_cached(segment)
        end

        check_cancelled!

        manifest = rendered_segments.map do |entry|
          {
            segment_id: entry[:segment].id,
            render_hash: entry[:render_hash],
            page_count: entry[:page_count],
            file_size: entry[:file_size]
          }
        end
        manifest_hash = Digest::SHA256.hexdigest(JSON.dump(manifest))

        compiled_pdf = stitch_segments(rendered_segments)
        compiled_pdf = apply_page_numbers(compiled_pdf) if page_numbers

        totals = derive_totals(compiled_pdf)
        storage_key = persist_compiled_pdf(compiled_pdf, totals[:version], totals[:filename])

        compiled_document = definition_document.event.documents.create!(
          logical_id: definition_document.logical_id,
          version: totals[:version],
          title: definition_document.title,
          client_visible: definition_document.client_visible,
          storage_uri: storage_key,
          checksum: totals[:checksum_md5],
          checksum_sha256: totals[:checksum_sha256],
          size_bytes: totals[:file_size],
          content_type: "application/pdf",
          source: Document::SOURCE_KEYS.first,
          doc_kind: Document::DOC_KINDS[:generated],
          manifest_hash: manifest_hash,
          build_id: build.build_id,
          built_by_user: built_by_user,
          compiled_page_count: totals[:page_count]
        )

        definition_document.update!(
          build_id: build.build_id,
          built_by_user: built_by_user,
          manifest_hash: manifest_hash,
          compiled_page_count: totals[:page_count]
        )

        Result.new(
          compiled_document: compiled_document,
          manifest_hash: manifest_hash,
          page_count: totals[:page_count],
          file_size: totals[:file_size],
          checksum_md5: totals[:checksum_md5],
          checksum_sha256: totals[:checksum_sha256]
        )
      end

      private

      attr_reader :definition_document, :build, :built_by_user, :segment_storage, :document_storage, :page_numbers

      def ensure_cached(segment)
        hash = SegmentHasher.call(segment)

        if segment.cached? && !segment.cache_stale?(hash)
          return cache_entry(segment)
        end

        check_cancelled!
        result = SegmentRenderer.new(segment).call
        if result.error.present?
          raise CompileError, "Segment ##{segment.id} failed to render: #{result.error}"
        end

        segment.update!(
          render_hash: result.render_hash,
          cached_pdf_key: result.storage_key,
          cached_pdf_generated_at: result.generated_at,
          cached_page_count: result.page_count,
          cached_file_size: result.file_size,
          last_render_error: nil
        )

        cache_entry(segment)
      end

      def cache_entry(segment)
        {
          segment: segment,
          render_hash: segment.render_hash,
          page_count: segment.cached_page_count,
          file_size: segment.cached_file_size
        }
      end

      def build_filename
        base = definition_document.title.to_s.parameterize
        base = "generated-packet" if base.blank?
        "#{base}.pdf"
      end

      def stitch_segments(rendered_segments)
        combined_pdf = CombinePDF.new

        rendered_segments.each do |entry|
          check_cancelled!
          pdf_data = segment_storage.download(entry[:segment].cached_pdf_key)
          unless pdf_data
            raise CompileError, "Cached PDF not found for segment ##{entry[:segment].id}"
          end

          buffer = pdf_data.respond_to?(:read) ? pdf_data.read : pdf_data
          buffer = buffer.to_s
          buffer.force_encoding(Encoding::BINARY)
          if buffer.empty?
            raise CompileError, "Cached PDF empty for segment ##{entry[:segment].id}"
          end

          combined_pdf << CombinePDF.parse(buffer)
        end

        combined_pdf.to_pdf
      end

      def apply_page_numbers(compiled_pdf)
        pdf = CombinePDF.parse(compiled_pdf)
        pdf.number_pages(**page_number_options)
        pdf.to_pdf
      end

      def page_number_options
        {
          start_at: 1,
          number_format: "pg. %s",
          location: :bottom_right,
          font_size: 10,
          margin_from_side: 10,
          y: 12,
          text_align: :right
        }
      end

      def derive_totals(compiled_pdf)
        pdf = CombinePDF.parse(compiled_pdf)
        page_count = pdf.pages.count
        file_size = compiled_pdf.bytesize
        checksum_md5 = Digest::MD5.hexdigest(compiled_pdf)
        checksum_sha256 = Digest::SHA256.hexdigest(compiled_pdf)
        version = Document.next_version_for(definition_document.logical_id)

        {
          page_count: page_count,
          file_size: file_size,
          checksum_md5: checksum_md5,
          checksum_sha256: checksum_sha256,
          version: version,
          filename: build_filename
        }
      end

      def persist_compiled_pdf(compiled_pdf, version, filename)
        check_cancelled!
        storage_key = DocumentStorage.build_key(
          event: definition_document.event,
          logical_id: definition_document.logical_id,
          version: version,
          filename: filename
        )

        document_storage.upload_io(storage_key, compiled_pdf, content_type: "application/pdf")
        storage_key
      rescue StandardError => e
        raise CompileError, "Failed to upload compiled PDF: #{e.message}"
      end

      def check_cancelled!
        if build.respond_to?(:reload) && build.persisted?
          build.reload
        end

        raise CancelledError, "Compile cancelled" if build.destroyed? || build.cancelled?
      end

      class CompileError < StandardError; end
      class CancelledError < StandardError; end
    end
  end
end
