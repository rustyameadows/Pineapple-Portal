require "digest"
require "stringio"

module RosAgent
  class SourceArtifactUploader
    ROOT = "agent-tasks".freeze

    def initialize(task:, files:, storage: R2::Storage.new, created_by: nil)
      @task = task
      @files = Array(files).reject(&:blank?)
      @storage = storage
      @created_by = created_by
    end

    def call
      files.each_with_index.map do |file, index|
        upload_file!(file, position: next_position + index)
      end
    end

    private

    attr_reader :task, :files, :storage, :created_by

    def upload_file!(file, position:)
      data = file.read
      filename = sanitized_filename(file)
      content_type = file.content_type.presence || "application/octet-stream"
      checksum = Digest::SHA256.hexdigest(data)
      storage_key = build_storage_key(filename)

      storage.upload_io(storage_key, StringIO.new(data), content_type: content_type)

      artifact = task.artifacts.create!(
        document: nil,
        document_logical_id: nil,
        filename: filename,
        content_type: content_type,
        size_bytes: data.bytesize,
        checksum: checksum,
        source_kind: AgentTaskArtifact::SOURCE_KINDS[:source_document],
        source_metadata_json: {
          "storage_uri" => storage_key,
          "uploaded_at" => Time.current.iso8601
        },
        position: position
      )

      task.append_event!(
        event_type: "source_file_uploaded",
        message: "Uploaded #{filename}.",
        payload: {
          filename: filename,
          content_type: content_type,
          size_bytes: data.bytesize,
          checksum: checksum,
          storage_uri: storage_key
        },
        created_by: created_by
      )

      artifact
    ensure
      file.rewind if file.respond_to?(:rewind)
    end

    def build_storage_key(filename)
      [ROOT, task.id, "source-inputs", SecureRandom.uuid, filename].join("/")
    end

    def sanitized_filename(file)
      DocumentStorage.sanitize_filename(file.original_filename.presence || "source-file")
    end

    def next_position
      task.artifacts.maximum(:position).to_i + 1
    end
  end
end
