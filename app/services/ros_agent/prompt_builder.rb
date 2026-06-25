module RosAgent
  class PromptBuilder
    MODE_INSTRUCTIONS = {
      initial_run: "Understand source documents, ask necessary questions, or draft the ROS.",
      answer_questions: "Use the planner's answers to continue the ROS draft.",
      refine_draft: "Revise the draft ROS scratchpad using the planner refinement.",
      request_final_plan: "Turn the latest draft ROS scratchpad into a final ROS change plan."
    }.freeze

    DRAFT_DETAIL_INSTRUCTIONS = [
      "The draft ROS must include every intended event item as draft_items.",
      "If the planner asks you to combine items from multiple sources, combine them and include the resulting event items in the draft.",
      "Do not merely reference future work like merging files, adding items later, or completing the ROS outside the draft.",
      "Use draft item details sparingly; most draft_items should have details: [].",
      "Details may only use field values notes, location, vendor_handling, staff_handling, or tags.",
      "Do not write TBD, placeholders, or generic cleanup commentary into details.",
      "Do not use details for reasoning such as source name removed, source vendor removed, or adapted from source.",
      "Notes are event-facing item subcopy only, not commentary on your work.",
      "Only include location, vendor handling, staff handling, or tags when the source or current event gives a genuinely useful value for that item."
    ].freeze
    VENDOR_INTENT_INSTRUCTIONS = [
      "Never assign, preserve, blank, convert, or placeholder vendors unless the planner explicitly instructs it.",
      "If the request does not mention vendors, ask a vendor-handling question.",
      "If the event has linked vendors, ask: Do you want me to leave vendors blank, or apply the vendors already linked to this event where they clearly fit?",
      "If the event has no linked vendors, ask: Do you want me to leave vendors blank, or convert source ROS vendor roles into temporary placeholders like DJ TBD or Catering TBD?",
      "If source vendor names appear, do not copy them unless the planner explicitly asks.",
      "If the planner asks for placeholders, use placeholder strings.",
      "If the planner asks for blanks, leave vendor fields blank.",
      "If the planner asks to use current event vendors, use only event-context vendors where the match is clear; ask again for ambiguous assignments."
    ].freeze

    def initialize(task:, mode:, event_context:, source_inputs:)
      @task = task
      @mode = mode.to_sym
      @event_context = event_context
      @source_inputs = source_inputs
    end

    def build
      {
        instructions: instructions,
        text: {
          format: Schemas::ResponseFormat.for_mode(mode)
        },
        input: [
          {
            role: "user",
            content: [{ type: "input_text", text: context_text }, *source_inputs]
          }
        ]
      }
    end

    private

    attr_reader :task, :mode, :event_context, :source_inputs

    def instructions
      [
        "You are Pineapple Portal's ROS planning agent.",
        "Existing-event scope only; do not create new events.",
        "Use raw source documents as evidence. Do not assume Rails parsed the source.",
        "Ask questions only when answers materially change the ROS.",
        "Maintain a draft ROS scratchpad before final approval.",
        "Return one of: source_understood, needs_input, draft_ready, ready_for_review.",
        *DRAFT_DETAIL_INSTRUCTIONS,
        *VENDOR_INTENT_INSTRUCTIONS,
        MODE_INSTRUCTIONS.fetch(mode, MODE_INSTRUCTIONS[:initial_run])
      ].join("\n")
    end

    def context_text
      {
        task_id: task.id,
        planner_prompt: task.prompt,
        event_context: event_context,
        source_artifacts: Array(task.artifacts).map { |artifact| { filename: artifact.filename } },
        source_understanding: source_understanding,
        draft_ros: task.draft_ros_json,
        question_answers: question_answers
      }.to_json
    end

    def source_understanding
      if task.respond_to?(:source_understanding_json)
        task.source_understanding_json
      else
        task.latest_source_understanding_json
      end
    end

    def question_answers
      Array(task.question_batches).filter_map do |batch|
        next unless batch.status.to_s == "answered"

        {
          questions: batch.questions_json,
          answers: batch.answers_json
        }
      end
    end
  end
end
