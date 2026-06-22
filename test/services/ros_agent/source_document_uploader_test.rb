require "test_helper"

module RosAgent
  class SourceDocumentUploaderTest < ActiveSupport::TestCase
    class FakeStorage
      attr_reader :downloaded_keys

      def initialize(downloads)
        @downloads = downloads
        @downloaded_keys = []
      end

      def download(key)
        @downloaded_keys << key
        content = @downloads[key]
        return unless content

        StringIO.new(content)
      end
    end

    class FakeClient
      attr_reader :file_payloads

      def initialize
        @file_payloads = []
      end

      def files_create(**payload)
        @file_payloads << payload
        { "id" => "file_uploaded_#{file_payloads.length}", "request_id" => "req_file_#{file_payloads.length}" }
      end
    end

    test "uploads source documents from R2 to OpenAI and stores file ids with local tracing" do
      task = agent_tasks(:draft_task)
      artifact = task.artifacts.create!(
        document: documents(:contract_v1),
        document_logical_id: documents(:contract_v1).logical_id,
        filename: "prior-run-of-show.csv",
        content_type: "text/csv",
        size_bytes: 128,
        checksum: "source-checksum",
        source_kind: AgentTaskArtifact::SOURCE_KINDS[:source_document],
        source_metadata_json: {},
        position: 2
      )
      storage = FakeStorage.new("documents/contract-v1.pdf" => "source file bytes")
      client = FakeClient.new

      assert_difference -> { task.llm_calls.count }, 1 do
        SourceDocumentUploader.new(task: task, client: client, storage: storage).call
      end

      assert_equal ["documents/contract-v1.pdf"], storage.downloaded_keys
      assert_equal "file_uploaded_1", artifact.reload.openai_file_id
      assert_equal 1, client.file_payloads.length
      assert_equal "user_data", client.file_payloads.first[:purpose]
      assert_instance_of OpenAI::FilePart, client.file_payloads.first[:file]
      assert_equal "prior-run-of-show.csv", client.file_payloads.first[:file].filename
      assert_equal "text/csv", client.file_payloads.first[:file].content_type

      call = task.llm_calls.order(:created_at).last
      assert_equal "file_upload", call.purpose
      assert_equal "openai-files", call.model
      assert_equal "completed", call.status
      assert_equal "file_uploaded_1", call.openai_response_id
      assert_equal "prior-run-of-show.csv", call.request_json.dig("file", "filename")
      refute_includes call.request_json.to_s, "source file bytes"
    end

    test "skips artifacts that already have OpenAI file ids" do
      task = agent_tasks(:draft_task)
      storage = FakeStorage.new({})
      client = FakeClient.new

      assert_no_difference -> { task.llm_calls.count } do
        SourceDocumentUploader.new(task: task, client: client, storage: storage).call
      end

      assert_empty storage.downloaded_keys
      assert_empty client.file_payloads
    end

    test "records failed upload traces when a source document cannot be downloaded" do
      task = agent_tasks(:draft_task)
      artifact = task.artifacts.create!(
        document: documents(:contract_v1),
        document_logical_id: documents(:contract_v1).logical_id,
        filename: "missing.pdf",
        content_type: "application/pdf",
        size_bytes: 128,
        checksum: "missing-checksum",
        source_kind: AgentTaskArtifact::SOURCE_KINDS[:source_document],
        source_metadata_json: {},
        position: 2
      )
      storage = FakeStorage.new({})

      assert_raises SourceDocumentUploader::MissingSourceError do
        SourceDocumentUploader.new(task: task, client: FakeClient.new, storage: storage).call
      end

      call = task.llm_calls.order(:created_at).last
      assert_equal "file_upload", call.purpose
      assert_equal "failed", call.status
      assert_nil artifact.reload.openai_file_id
      assert_match "missing.pdf", call.error_json["message"]
    end
  end
end
