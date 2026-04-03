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
        bundle = packet_bundle.call
        totals = derive_totals(bundle.pdf_data)
        storage_key = persist_compiled_pdf(bundle.pdf_data, totals[:version], totals[:filename])

        compiled_document = definition_document.event.documents.create!(
          logical_id: definition_document.logical_id,
          version: totals[:version],
          title: definition_document.title,
          client_visible: definition_document.client_visible,
          packet_schema_version: definition_document.packet_schema_version,
          storage_uri: storage_key,
          checksum: totals[:checksum_md5],
          checksum_sha256: totals[:checksum_sha256],
          size_bytes: totals[:file_size],
          content_type: "application/pdf",
          source: Document::SOURCE_KEYS.first,
          doc_kind: Document::DOC_KINDS[:generated],
          manifest_hash: bundle.manifest_hash,
          build_id: build.build_id,
          built_by_user: built_by_user,
          compiled_page_count: totals[:page_count]
        )

        definition_document.update!(
          build_id: build.build_id,
          built_by_user: built_by_user,
          manifest_hash: bundle.manifest_hash,
          compiled_page_count: totals[:page_count]
        )

        Result.new(
          compiled_document: compiled_document,
          manifest_hash: bundle.manifest_hash,
          page_count: totals[:page_count],
          file_size: totals[:file_size],
          checksum_md5: totals[:checksum_md5],
          checksum_sha256: totals[:checksum_sha256]
        )
      end

      private

      attr_reader :definition_document, :build, :built_by_user, :segment_storage, :document_storage, :page_numbers

      def build_filename
        base = definition_document.title.to_s.parameterize
        base = "generated-packet" if base.blank?
        "#{base}.pdf"
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

      def packet_bundle
        @packet_bundle ||= PacketBundle.new(
          definition_document: definition_document,
          segment_storage: segment_storage,
          page_numbers: page_numbers,
          check_cancelled: method(:check_cancelled!)
        )
      end

      class CompileError < StandardError; end
      class CancelledError < StandardError; end
    end
  end
end
