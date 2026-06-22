module RosAgent
  class PromptBuilder
    MODE_INSTRUCTIONS = {
      initial_run: "Understand source documents, ask necessary questions, or draft the ROS.",
      answer_questions: "Use the planner's answers to continue the ROS draft.",
      refine_draft: "Revise the draft ROS scratchpad using the planner refinement.",
      request_final_plan: "Turn the latest draft ROS scratchpad into a final ROS change plan."
    }.freeze

    def initialize(task:, mode:, event_context:, source_inputs:)
      @task = task
      @mode = mode.to_sym
      @event_context = event_context
      @source_inputs = source_inputs
    end

    def build
      {
        instructions: instructions,
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
