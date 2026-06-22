require "test_helper"

module RosAgent
  class PromptBuilderTest < ActiveSupport::TestCase
    FakeArtifact = Struct.new(:filename, keyword_init: true)
    FakeQuestionBatch = Struct.new(:questions_json, :answers_json, :status, keyword_init: true)
    FakeTask = Struct.new(
      :id,
      :event,
      :prompt,
      :artifacts,
      :source_understanding_json,
      :draft_ros_json,
      :question_batches,
      keyword_init: true
    )

    test "builds initial-run instructions and input with event context, defaults, and source artifact details" do
      task = build_task
      event_context = {
        event: { id: events(:one).id, starts_on: events(:one).starts_on.to_s },
        defaults: { tags: [{ name: "Day Of" }] }
      }
      source_inputs = [{ type: "input_file", file_id: "file_source_123", filename: "millar_sample.csv" }]

      payload = PromptBuilder.new(
        task: task,
        mode: :initial_run,
        event_context: event_context,
        source_inputs: source_inputs
      ).build

      assert_includes payload[:instructions], "Existing-event scope only"
      assert_includes payload[:instructions], "Return one of: source_understood, needs_input, draft_ready, ready_for_review"

      content = payload.dig(:input, 0, :content).filter_map { |entry| entry[:text] }.join("\n")

      assert_includes content, events(:one).id.to_s
      assert_includes content, events(:one).starts_on.to_s
      assert_includes content, "Day Of"
      assert_includes content, "millar_sample.csv"
      assert_includes content, task.prompt
    end

    test "includes source understanding, question answers, and draft scratchpad for refinement modes" do
      task = build_task(
        source_understanding_json: { "overall_read" => "Two-day entertainment-heavy event." },
        draft_ros_json: { "draft_days" => [{ "label" => "Wedding Day" }] },
        question_batches: [
          FakeQuestionBatch.new(
            status: "answered",
            questions_json: [{ "key" => "date_mapping", "label" => "Date Mapping" }],
            answers_json: { "date_mapping" => "map_saturday_to_wedding_date" }
          )
        ]
      )

      payload = PromptBuilder.new(
        task: task,
        mode: :request_final_plan,
        event_context: { event: { id: events(:one).id } },
        source_inputs: []
      ).build

      content = payload.dig(:input, 0, :content).filter_map { |entry| entry[:text] }.join("\n")

      assert_includes payload[:instructions], "Turn the latest draft ROS scratchpad into a final ROS change plan"
      assert_includes content, "Two-day entertainment-heavy event."
      assert_includes content, "map_saturday_to_wedding_date"
      assert_includes content, "Wedding Day"
    end

    private

    def build_task(source_understanding_json: {}, draft_ros_json: {}, question_batches: [])
      FakeTask.new(
        id: 42,
        event: events(:one),
        prompt: "Adapt the attached prior event run of show for this wedding.",
        artifacts: [FakeArtifact.new(filename: "millar_sample.csv")],
        source_understanding_json: source_understanding_json,
        draft_ros_json: draft_ros_json,
        question_batches: question_batches
      )
    end
  end
end
