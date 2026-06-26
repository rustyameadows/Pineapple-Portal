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
      assert_equal "json_schema", payload.dig(:text, :format, :type)
      assert_equal true, payload.dig(:text, :format, :strict)

      content = payload.dig(:input, 0, :content).filter_map { |entry| entry[:text] }.join("\n")

      assert_includes content, events(:one).id.to_s
      assert_includes content, events(:one).starts_on.to_s
      assert_includes content, "Day Of"
      assert_includes content, "millar_sample.csv"
      assert_includes content, task.prompt
    end

    test "instructs sparse draft details without generic cleanup commentary" do
      payload = PromptBuilder.new(
        task: build_task,
        mode: :initial_run,
        event_context: { event: { id: events(:one).id } },
        source_inputs: []
      ).build

      assert_includes payload[:instructions], "Use draft item details sparingly"
      assert_includes payload[:instructions], "Do not write TBD"
      assert_includes payload[:instructions], "source name removed"
      assert_includes payload[:instructions], "Notes are event-facing item subcopy"
    end

    test "instructs the draft to include every intended event item" do
      payload = PromptBuilder.new(
        task: build_task,
        mode: :initial_run,
        event_context: { event: { id: events(:one).id } },
        source_inputs: []
      ).build

      assert_includes payload[:instructions], "The draft ROS must include every intended event item as draft_items."
      assert_includes payload[:instructions], "If the planner asks you to combine items from multiple sources, combine them and include the resulting event items in the draft."
      assert_includes payload[:instructions], "Do not merely reference future work like merging files, adding items later, or completing the ROS outside the draft."
      assert_includes payload[:instructions], "IMPORTANT: the draft ROS must contain multiple event items and should include all items that will eventually be included in the final ROS."
    end

    test "instructs the agent how to use time captions" do
      payload = PromptBuilder.new(
        task: build_task,
        mode: :initial_run,
        event_context: { event: { id: events(:one).id } },
        source_inputs: []
      ).build

      assert_includes payload[:instructions], "Use time_caption for display labels like All day, EOD, TBD, or timing coming soon."
      assert_includes payload[:instructions], "time_caption is not a substitute for starts_at"
      assert_includes payload[:instructions], "Do not use time_caption for normal exact clock times"
    end

    test "instructs the agent not to create conceptual day labels or day sections" do
      payload = PromptBuilder.new(
        task: build_task,
        mode: :initial_run,
        event_context: { event: { id: events(:one).id } },
        source_inputs: []
      ).build

      assert_includes payload[:instructions], "Do not create conceptual day labels or day sections as work product."
      assert_includes payload[:instructions], "The app groups by actual item dates."
      assert_includes payload[:instructions], "Day labels are not a substitute for items."
    end

    test "requires explicit planner intent before writing vendor values" do
      payload = PromptBuilder.new(
        task: build_task,
        mode: :initial_run,
        event_context: { event: { id: events(:one).id } },
        source_inputs: []
      ).build

      assert_includes payload[:instructions], "Never assign, preserve, blank, convert, or placeholder vendors unless the planner explicitly instructs it."
      assert_includes payload[:instructions], "If the request does not mention vendors, ask a vendor-handling question."
      assert_includes payload[:instructions], "Do you want me to leave vendors blank, or apply the vendors already linked to this event where they clearly fit?"
      assert_includes payload[:instructions], "Do you want me to leave vendors blank, or convert source ROS vendor roles into temporary placeholders like DJ TBD or Catering TBD?"
      assert_includes payload[:instructions], "If source vendor names appear, do not copy them unless the planner explicitly asks."
      assert_includes payload[:instructions], "If the planner asks for placeholders, use placeholder strings."
      assert_includes payload[:instructions], "If the planner asks for blanks, leave vendor fields blank."
      assert_includes payload[:instructions], "If the planner asks to use current event vendors, use only event-context vendors where the match is clear; ask again for ambiguous assignments."
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
      assert_equal "ros_agent_request_final_plan_response", payload.dig(:text, :format, :name)
      assert_includes content, "Two-day entertainment-heavy event."
      assert_includes content, "map_saturday_to_wedding_date"
      assert_includes content, "Wedding Day"
    end

    test "request final plan mode requires faithful draft item coverage" do
      payload = PromptBuilder.new(
        task: build_task,
        mode: :request_final_plan,
        event_context: { event: { id: events(:one).id } },
        source_inputs: []
      ).build

      assert_includes payload[:instructions], "You are finalizing a planner-reviewed detailed draft into approval-ready calendar operations."
      assert_includes payload[:instructions], "Do not summarize, compress, deduplicate, or sample draft_items."
      assert_includes payload[:instructions], "Repeated titles on different dates are separate calendar items."
      assert_includes payload[:instructions], "Every draft item that should exist in the ROS must become a create_item or update_item operation."
      assert_includes payload[:instructions], "Before returning ready_for_review, compare the draft_items count to the create_item/update_item operations that represent them."
      assert_includes payload[:instructions], "This is not a narrative plan or summary."
      assert_includes payload[:instructions], "Each operation is one database write the app will perform."
      assert_includes payload[:instructions], "There is no bulk create operation."
      assert_includes payload[:instructions], "Rails will not expand references to draft_items."
      assert_includes payload[:instructions], "If the draft has 198 item rows and all should be created, return 198 create_item operations."
    end

    test "answer question mode tells the agent to use planner answers" do
      task = build_task(
        question_batches: [
          FakeQuestionBatch.new(
            status: "answered",
            questions_json: [{ "key" => "prior_day_setup", "label" => "Prior-day setup" }],
            answers_json: { "prior_day_setup" => "wedding_day_only" }
          )
        ]
      )

      payload = PromptBuilder.new(
        task: task,
        mode: :answer_questions,
        event_context: { event: { id: events(:one).id } },
        source_inputs: []
      ).build

      content = payload.dig(:input, 0, :content).filter_map { |entry| entry[:text] }.join("\n")

      assert_includes payload[:instructions], "Use the planner's answers to continue the ROS draft"
      assert_includes content, "wedding_day_only"
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
