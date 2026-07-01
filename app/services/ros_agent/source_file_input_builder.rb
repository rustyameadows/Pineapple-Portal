module RosAgent
  class SourceFileInputBuilder
    TEXT_CONTENT_TYPES = %w[text/csv text/plain text/tab-separated-values application/json].freeze
    MAX_PREVIEW_BYTES = 50.kilobytes

    def initialize(task)
      @task = task
    end

    def build
      artifacts.sort_by { |artifact| artifact.position.to_i }.filter_map do |artifact|
        if artifact.openai_file_id.present?
          {
            type: "input_file",
            file_id: artifact.openai_file_id
          }
        elsif text_like?(artifact)
          text_preview_input(artifact)
        end
      end
    end

    private

    attr_reader :task

    def artifacts
      Array(task.artifacts)
    end

    def text_like?(artifact)
      TEXT_CONTENT_TYPES.include?(artifact.content_type.to_s)
    end

    def text_preview_input(artifact)
      path = artifact.source_metadata_json.to_h["local_path"]
      return unless path.present? && File.file?(path)

      text = File.binread(path, MAX_PREVIEW_BYTES)
      {
        type: "input_text",
        text: "Source file: #{artifact.filename}\n\n#{text}"
      }
    end
  end
end
