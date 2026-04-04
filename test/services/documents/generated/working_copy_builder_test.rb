require "test_helper"

module Documents
  module Generated
    class WorkingCopyBuilderTest < ActiveSupport::TestCase
      class DocumentStorageStub
        attr_reader :uploaded_key, :uploaded_data, :uploaded_content_type

        def upload_io(key, data, content_type:)
          @uploaded_key = key
          @uploaded_data = data
          @uploaded_content_type = content_type
        end
      end

      class PacketBundleStub
        attr_reader :build_calls

        def initialize(manifest_hash:, result:)
          @manifest_hash = manifest_hash
          @result = result
          @build_calls = 0
        end

        def prepare
          PacketBundle::PreparedEntries.new(entries: [], rendered_entries: [], manifest_hash: @manifest_hash)
        end

        def build_from_prepared(_prepared)
          @build_calls += 1
          @result
        end
      end

      setup do
        @event = events(:one)
        @document = @event.documents.create!(
          title: "Generated Packet",
          doc_kind: Document::DOC_KINDS[:generated],
          logical_id: SecureRandom.uuid,
          version: 1,
          is_latest: false,
          client_visible: false,
          source: "packet",
          packet_schema_version: Document::PACKET_SCHEMA_VERSIONS[:source_backed]
        )
        @document_storage = DocumentStorageStub.new
      end

      test "reuses the current working copy when the manifest already matches" do
        @document.update!(
          working_storage_uri: "documents/#{@event.id}/#{@document.logical_id}/working/generated-packet-working.pdf",
          working_manifest_hash: "same-manifest",
          working_rendered_at: Time.current,
          working_status: Document::WORKING_STATUSES[:refreshing]
        )

        bundle_stub = PacketBundleStub.new(manifest_hash: "same-manifest", result: nil)

        PacketBundle.stub :new, ->(**) { bundle_stub } do
          result = WorkingCopyBuilder.new(
            definition_document: @document,
            document_storage: @document_storage
          ).call

          assert_equal @document.working_storage_uri, result.storage_key
          assert_nil @document_storage.uploaded_key
          assert_equal 0, bundle_stub.build_calls
          assert_equal Document::WORKING_STATUSES[:fresh], @document.reload.working_status
        end
      end

      test "uploads a new working copy when the manifest changes" do
        bundle_result = PacketBundle::Result.new(
          entries: [],
          manifest_hash: "new-manifest",
          pdf_data: "PDF_DATA",
          page_count: 2,
          file_size: 64,
          checksum_md5: "md5",
          checksum_sha256: "sha256"
        )
        bundle_stub = PacketBundleStub.new(manifest_hash: "new-manifest", result: bundle_result)

        PacketBundle.stub :new, ->(**) { bundle_stub } do
          result = WorkingCopyBuilder.new(
            definition_document: @document,
            document_storage: @document_storage
          ).call

          assert_includes result.storage_key, "/working/"
          assert_equal "PDF_DATA", @document_storage.uploaded_data
          assert_equal 1, bundle_stub.build_calls
          assert_equal "new-manifest", @document.reload.working_manifest_hash
          assert_equal Document::WORKING_STATUSES[:fresh], @document.working_status
        end
      end
    end
  end
end
