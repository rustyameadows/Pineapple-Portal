require "stringio"
require "openai"

module RosAgent
  class SourceDocumentUploader
    PURPOSE = "user_data".freeze
    MODEL_LABEL = "openai-files".freeze

    class MissingSourceError < StandardError; end

    def initialize(task:, client: OpenaiClient.new, storage: R2::Storage.new, trace_recorder_class: TraceRecorder)
      @task = task
      @client = client
      @storage = storage
      @trace_recorder_class = trace_recorder_class
    end

    def call
      uploadable_artifacts.each do |artifact|
        next if artifact.openai_file_id.present?

        upload_artifact!(artifact)
      end
    end

    private

    attr_reader :task, :client, :storage, :trace_recorder_class

    def uploadable_artifacts
      task.artifacts
          .select { |artifact| artifact.source_kind == AgentTaskArtifact::SOURCE_KINDS[:source_document] }
          .sort_by { |artifact| artifact.position.to_i }
    end

    def upload_artifact!(artifact)
      request_snapshot = request_snapshot_for(artifact)
      recorder = trace_recorder_for(request_snapshot)
      recorder.start!

      file_io = download_source!(artifact)
      response = client.files_create(
        file: OpenAI::FilePart.new(file_io, filename: artifact.filename, content_type: artifact.content_type),
        purpose: PURPOSE
      )
      recorder.complete!(response: response)

      artifact.update!(
        openai_file_id: response_value(response, "id"),
        source_metadata_json: artifact.source_metadata_json.to_h.merge(
          "openai_uploaded_at" => Time.current.iso8601,
          "openai_purpose" => PURPOSE
        )
      )
    rescue StandardError => e
      recorder&.fail!(error: e, response: {})
      raise
    end

    def download_source!(artifact)
      key = storage_key_for(artifact)
      raise MissingSourceError, "Source document #{artifact.filename} is missing a storage key." if key.blank?

      io = storage.download(key)
      raise MissingSourceError, "Source document #{artifact.filename} could not be downloaded from storage." unless io

      io
    end

    def storage_key_for(artifact)
      artifact.document&.storage_uri.presence || artifact.source_metadata_json.to_h["storage_uri"]
    end

    def request_snapshot_for(artifact)
      {
        purpose: PURPOSE,
        file: {
          filename: artifact.filename,
          content_type: artifact.content_type,
          size_bytes: artifact.size_bytes,
          storage_uri: storage_key_for(artifact)
        }
      }
    end

    def trace_recorder_for(request_snapshot)
      trace_recorder_class.new(
        task: task,
        purpose: "file_upload",
        model: MODEL_LABEL,
        request_payload: request_snapshot
      )
    end

    def response_value(object, key)
      if object.respond_to?(:[])
        object[key] || object[key.to_sym]
      elsif object.respond_to?(key)
        object.public_send(key)
      end
    end
  end
end
