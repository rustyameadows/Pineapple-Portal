require "test_helper"

module Documents
  module Generated
    class WorkingCopyBuilderTest < ActiveSupport::TestCase
      class BuildRunnerStub
        attr_reader :calls

        def initialize(result)
          @result = result
          @calls = []
        end

        def call
          calls << true
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
      end

      test "creates a working build and mirrors the runner result onto the document" do
        runner_result = Struct.new(
          :manifest_hash,
          :page_count,
          :file_size,
          :checksum_sha256,
          :storage_uri,
          :page_numbers,
          keyword_init: true
        ).new(
          manifest_hash: "new-manifest",
          page_count: 2,
          file_size: 64,
          checksum_sha256: "sha256",
          storage_uri: "documents/#{@event.id}/#{@document.logical_id}/working/generated-packet-working.pdf",
          page_numbers: true
        )
        runner_stub = BuildRunnerStub.new(runner_result)
        segment_storage = Object.new
        document_storage = Object.new
        build_runner_kwargs = nil

        BuildRunner.stub :new, ->(**kwargs) {
          build_runner_kwargs = kwargs
          runner_stub
        } do
          result = WorkingCopyBuilder.new(
            definition_document: @document,
            segment_storage: segment_storage,
            document_storage: document_storage
          ).call

          build = @document.working_builds.recent_first.first
          assert_equal 1, runner_stub.calls.length
          assert_equal build, build_runner_kwargs[:build]
          assert_same segment_storage, build_runner_kwargs[:segment_storage]
          assert_same document_storage, build_runner_kwargs[:document_storage]
          assert_equal DocumentBuild::STATUSES[:succeeded], build.status
          assert_equal DocumentBuild::BUILD_KINDS[:working], build.build_kind
          assert_equal runner_result.storage_uri, result.storage_key
          assert_equal "new-manifest", @document.reload.working_manifest_hash
          assert_equal Document::WORKING_STATUSES[:fresh], @document.working_status_key
        end
      end
    end
  end
end
