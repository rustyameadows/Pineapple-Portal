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
        :storage_uri,
        :page_numbers,
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
        report_progress(stage: :preparing_pdf)

        if working_build?
          compile_working_build
        else
          compile_snapshot_build
        end
      end

      private

      attr_reader :definition_document, :build, :built_by_user, :segment_storage, :document_storage, :page_numbers

      def compile_snapshot_build
        manifest = PacketManifest.new(definition_document: definition_document).call
        persist_requested_manifest!(manifest.manifest_hash)

        compiled = compiled_snapshot_payload(manifest)
        totals = derive_totals(compiled[:pdf_data], version: Document.next_version_for(definition_document.logical_id))
        report_progress(stage: :uploading_pdf)
        storage_key = persist_snapshot_pdf(compiled[:pdf_data], totals[:version], totals[:filename])
        report_progress(stage: :finalizing_pdf)

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
          manifest_hash: compiled[:manifest_hash],
          build_id: build.build_id,
          built_by_user: built_by_user,
          compiled_page_count: totals[:page_count]
        )

        definition_document.update!(
          build_id: build.build_id,
          built_by_user: built_by_user,
          manifest_hash: compiled[:manifest_hash],
          compiled_page_count: totals[:page_count]
        )

        Result.new(
          compiled_document: compiled_document,
          manifest_hash: compiled[:manifest_hash],
          page_count: totals[:page_count],
          file_size: totals[:file_size],
          checksum_md5: totals[:checksum_md5],
          checksum_sha256: totals[:checksum_sha256],
          storage_uri: storage_key,
          page_numbers: page_numbers
        )
      end

      def compile_working_build
        manifest = PacketManifest.new(definition_document: definition_document).call
        persist_requested_manifest!(manifest.manifest_hash)

        prepared = packet_bundle.prepare
        reusable_build = current_working_build(prepared.manifest_hash, allow_legacy: false)

        if reusable_build.present?
          report_progress(stage: :preparing_pdf, message: "Using the current live PDF")
          report_progress(stage: :finalizing_pdf)
          mirror_working_copy!(
            storage_uri: reusable_build.storage_uri,
            manifest_hash: reusable_build.manifest_hash,
            checksum_sha256: reusable_build.checksum_sha256,
            page_count: reusable_build.compiled_page_count,
            file_size: reusable_build.file_size,
            rendered_at: reusable_build.rendered_at || Time.current
          )

          return Result.new(
            manifest_hash: reusable_build.manifest_hash,
            page_count: reusable_build.compiled_page_count,
            file_size: reusable_build.file_size,
            checksum_sha256: reusable_build.checksum_sha256,
            storage_uri: reusable_build.storage_uri,
            page_numbers: true
          )
        end

        bundle = packet_bundle.build_from_prepared(prepared)
        report_progress(stage: :uploading_pdf)
        storage_key = persist_working_pdf(bundle.pdf_data)
        report_progress(stage: :finalizing_pdf)

        mirror_working_copy!(
          storage_uri: storage_key,
          manifest_hash: bundle.manifest_hash,
          checksum_sha256: bundle.checksum_sha256,
          page_count: bundle.page_count,
          file_size: bundle.file_size,
          rendered_at: Time.current
        )

        Result.new(
          manifest_hash: bundle.manifest_hash,
          page_count: bundle.page_count,
          file_size: bundle.file_size,
          checksum_md5: bundle.checksum_md5,
          checksum_sha256: bundle.checksum_sha256,
          storage_uri: storage_key,
          page_numbers: true
        )
      end

      def compiled_snapshot_payload(manifest)
        live_pdf = current_working_pdf(manifest)

        if live_pdf.present?
          report_progress(stage: :preparing_pdf, message: "Using the current live PDF")
          return { pdf_data: live_pdf, manifest_hash: manifest.manifest_hash }
        end

        bundle = packet_bundle.call
        { pdf_data: bundle.pdf_data, manifest_hash: bundle.manifest_hash }
      end

      def derive_totals(compiled_pdf, version:)
        pdf = CombinePDF.parse(compiled_pdf)
        page_count = pdf.pages.count
        file_size = compiled_pdf.bytesize
        checksum_md5 = Digest::MD5.hexdigest(compiled_pdf)
        checksum_sha256 = Digest::SHA256.hexdigest(compiled_pdf)

        {
          page_count: page_count,
          file_size: file_size,
          checksum_md5: checksum_md5,
          checksum_sha256: checksum_sha256,
          version: version,
          filename: build_filename
        }
      end

      def persist_snapshot_pdf(compiled_pdf, version, filename)
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

      def persist_working_pdf(compiled_pdf)
        check_cancelled!
        storage_key = DocumentStorage.build_working_key(
          event: definition_document.event,
          logical_id: definition_document.logical_id,
          filename: build_filename(suffix: "-working")
        )

        document_storage.upload_io(storage_key, compiled_pdf, content_type: "application/pdf")
        storage_key
      rescue StandardError => e
        raise CompileError, "Failed to upload live PDF: #{e.message}"
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
          page_numbers: effective_page_numbers,
          check_cancelled: method(:check_cancelled!),
          progress_reporter: method(:report_progress)
        )
      end

      def current_working_pdf(manifest)
        return unless page_numbers

        working_build = current_working_build(manifest.manifest_hash)
        storage_key = working_build&.storage_uri
        return unless storage_key.present?
        return unless manifest.entries.count { |entry| entry.source.cached_page_count.present? } == manifest.entries.count

        data = document_storage.download(storage_key)
        buffer = data.respond_to?(:read) ? data.read : data
        buffer = buffer.to_s
        buffer.force_encoding(Encoding::BINARY)
        buffer.presence
      rescue StandardError
        nil
      end

      def current_working_build(manifest_hash, allow_legacy: true)
        build = definition_document.working_builds.successful.recent_first.find do |candidate|
          candidate.storage_uri.present? &&
            candidate.page_numbers != false &&
            candidate.manifest_hash == manifest_hash
        end
        return build if build.present?
        return unless allow_legacy
        return unless definition_document[:working_storage_uri].present?
        return unless definition_document[:working_manifest_hash] == manifest_hash

        Struct.new(:storage_uri, :manifest_hash, :checksum_sha256, :compiled_page_count, :file_size, :rendered_at, :page_numbers).new(
          definition_document[:working_storage_uri],
          definition_document[:working_manifest_hash],
          definition_document[:working_checksum_sha256],
          definition_document[:working_page_count],
          definition_document[:working_file_size],
          definition_document[:working_rendered_at],
          true
        )
      end

      def mirror_working_copy!(storage_uri:, manifest_hash:, checksum_sha256:, page_count:, file_size:, rendered_at:)
        definition_document.mark_working_fresh!(
          working_storage_uri: storage_uri,
          working_manifest_hash: manifest_hash,
          working_checksum_sha256: checksum_sha256,
          working_page_count: page_count,
          working_file_size: file_size,
          working_rendered_at: rendered_at
        )
      end

      def working_build?
        build.respond_to?(:working?) && build.working?
      end

      def effective_page_numbers
        working_build? ? true : page_numbers
      end

      def persist_requested_manifest!(manifest_hash)
        return if manifest_hash.blank?
        return unless build.respond_to?(:manifest_hash)
        return unless build.respond_to?(:update!)
        return if build.manifest_hash == manifest_hash

        build.update!(manifest_hash: manifest_hash)
      end

      def build_filename(suffix: nil)
        base = definition_document.title.to_s.parameterize
        base = "generated-packet" if base.blank?
        "#{base}#{suffix}.pdf"
      end

      def report_progress(...)
        build.report_progress!(...) if build.respond_to?(:report_progress!)
      end

      class CompileError < StandardError; end
      class CancelledError < StandardError; end
    end
  end
end
