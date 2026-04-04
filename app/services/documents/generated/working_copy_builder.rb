module Documents
  module Generated
    class WorkingCopyBuilder
      Result = Struct.new(
        :storage_key,
        :manifest_hash,
        :page_count,
        :file_size,
        :checksum_sha256,
        keyword_init: true
      )

      def initialize(definition_document:, segment_storage: R2Storage.new, document_storage: R2::Storage.new)
        @definition_document = definition_document
        @segment_storage = segment_storage
        @document_storage = document_storage
      end

      def call
        packet_bundle = PacketBundle.new(
          definition_document: definition_document,
          segment_storage: segment_storage,
          page_numbers: false
        )
        prepared = packet_bundle.prepare

        if working_copy_current?(prepared.manifest_hash)
          definition_document.mark_working_fresh!
          return Result.new(
            storage_key: definition_document.working_storage_uri,
            manifest_hash: definition_document.working_manifest_hash,
            page_count: definition_document.working_page_count,
            file_size: definition_document.working_file_size,
            checksum_sha256: definition_document.working_checksum_sha256
          )
        end

        storage_key = DocumentStorage.build_working_key(
          event: definition_document.event,
          logical_id: definition_document.logical_id,
          filename: build_filename
        )
        bundle = packet_bundle.build_from_prepared(prepared)
        document_storage.upload_io(storage_key, bundle.pdf_data, content_type: "application/pdf")

        definition_document.mark_working_fresh!(
          working_storage_uri: storage_key,
          working_manifest_hash: bundle.manifest_hash,
          working_checksum_sha256: bundle.checksum_sha256,
          working_page_count: bundle.page_count,
          working_file_size: bundle.file_size,
          working_rendered_at: Time.current
        )

        Result.new(
          storage_key: storage_key,
          manifest_hash: bundle.manifest_hash,
          page_count: bundle.page_count,
          file_size: bundle.file_size,
          checksum_sha256: bundle.checksum_sha256
        )
      end

      private

      attr_reader :definition_document, :segment_storage, :document_storage

      def working_copy_current?(manifest_hash)
        definition_document.working_storage_uri.present? &&
          definition_document.working_manifest_hash == manifest_hash
      end

      def build_filename
        base = definition_document.title.to_s.parameterize
        base = "generated-packet" if base.blank?
        "#{base}-working.pdf"
      end
    end
  end
end
