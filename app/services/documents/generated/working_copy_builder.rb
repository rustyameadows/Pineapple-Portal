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

      def initialize(definition_document:, segment_storage: nil, document_storage: nil)
        @definition_document = definition_document
        @segment_storage = segment_storage
        @document_storage = document_storage
      end

      def call
        definition_document.request_working_refresh!

        build = definition_document.builds.create!(
          status: DocumentBuild::STATUSES[:pending],
          build_kind: DocumentBuild::BUILD_KINDS[:working],
          built_by_user: definition_document.built_by_user,
          page_numbers: true
        )
        build.report_progress!(stage: :queued)
        build.mark_running!

        result = BuildRunner.new(
          build: build,
          segment_storage: segment_storage,
          document_storage: document_storage
        ).call
        build.mark_succeeded!(result)

        Result.new(
          storage_key: result.storage_uri,
          manifest_hash: result.manifest_hash,
          page_count: result.page_count,
          file_size: result.file_size,
          checksum_sha256: result.checksum_sha256
        )
      rescue StandardError => e
        build&.mark_failed!(e)
        definition_document.mark_working_failed!(e.message)
        raise
      end

      private

      attr_reader :definition_document

      def segment_storage
        @segment_storage ||= R2Storage.new
      end

      def document_storage
        @document_storage ||= R2::Storage.new
      end

    end
  end
end
