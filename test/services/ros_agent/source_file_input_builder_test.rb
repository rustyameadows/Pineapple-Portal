require "test_helper"

module RosAgent
  class SourceFileInputBuilderTest < ActiveSupport::TestCase
    FakeArtifact = Struct.new(
      :filename,
      :content_type,
      :openai_file_id,
      :position,
      :source_metadata_json,
      keyword_init: true
    )

    FakeTask = Struct.new(:artifacts, keyword_init: true)

    test "uses OpenAI file references when artifacts have uploaded ids" do
      task = FakeTask.new(
        artifacts: [
          FakeArtifact.new(
            filename: "millar.pdf",
            content_type: "application/pdf",
            openai_file_id: "file_pdf_123",
            position: 2,
            source_metadata_json: {}
          ),
          FakeArtifact.new(
            filename: "photo.png",
            content_type: "image/png",
            openai_file_id: "file_img_123",
            position: 1,
            source_metadata_json: {}
          ),
          FakeArtifact.new(
            filename: "schedule.xlsx",
            content_type: "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
            openai_file_id: "file_xlsx_123",
            position: 3,
            source_metadata_json: {}
          )
        ]
      )

      inputs = SourceFileInputBuilder.new(task).build

      assert_equal [
        { type: "input_file", file_id: "file_img_123", filename: "photo.png" },
        { type: "input_file", file_id: "file_pdf_123", filename: "millar.pdf" },
        { type: "input_file", file_id: "file_xlsx_123", filename: "schedule.xlsx" }
      ], inputs
    end

    test "falls back to a small text preview for text-like fixtures without an OpenAI file id" do
      task = FakeTask.new(
        artifacts: [
          FakeArtifact.new(
            filename: "millar_sample.csv",
            content_type: "text/csv",
            position: 1,
            source_metadata_json: {
              "local_path" => file_fixture("millar_sample.csv").to_s
            }
          )
        ]
      )

      inputs = SourceFileInputBuilder.new(task).build

      assert_equal 1, inputs.length
      assert_equal "input_text", inputs.first[:type]
      assert_includes inputs.first[:text], "Source file: millar_sample.csv"
      assert_includes inputs.first[:text], "Friday, June 13"
      assert_includes inputs.first[:text], "Saturday, June 14"
    end

    test "skips binary artifacts that have no uploaded OpenAI file id" do
      task = FakeTask.new(
        artifacts: [
          FakeArtifact.new(
            filename: "source.pdf",
            content_type: "application/pdf",
            position: 1,
            source_metadata_json: {}
          )
        ]
      )

      assert_equal [], SourceFileInputBuilder.new(task).build
    end
  end
end
