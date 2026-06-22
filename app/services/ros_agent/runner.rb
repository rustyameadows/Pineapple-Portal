module RosAgent
  class Runner
    MODEL = "gpt-5.5".freeze
    REASONING_EFFORT = "high".freeze

    def initialize(task:,
                   client: OpenaiClient.new,
                   prompt_builder_class: PromptBuilder,
                   source_file_input_builder_class: SourceFileInputBuilder,
                   event_context_class: EventContext,
                   trace_recorder_class: TraceRecorder)
      @task = task
      @client = client
      @prompt_builder_class = prompt_builder_class
      @source_file_input_builder_class = source_file_input_builder_class
      @event_context_class = event_context_class
      @trace_recorder_class = trace_recorder_class
    end

    def call(mode: :initial_run)
      mark_status!("analyzing")
      request_payload = build_request_payload(mode)
      recorder = trace_recorder_for(request_payload)
      recorder.start!

      response = client.responses_create(**request_payload)
      recorder.complete!(response: response)
      handle_response(response)
    rescue StandardError => e
      recorder&.fail!(error: e, response: {})
      mark_failure!(e)
      raise
    end

    private

    attr_reader :task, :client, :prompt_builder_class, :source_file_input_builder_class, :event_context_class, :trace_recorder_class

    def build_request_payload(mode)
      prompt_payload = prompt_builder_class.new(
        task: task,
        mode: mode,
        event_context: event_context_class.new(task.event).as_json,
        source_inputs: source_file_input_builder_class.new(task).build
      ).build

      {
        model: model,
        reasoning: { effort: reasoning_effort },
        **prompt_payload
      }
    end

    def trace_recorder_for(request_payload)
      if trace_recorder_class.respond_to?(:call)
        trace_recorder_class.call(
          task: task,
          purpose: purpose_for_request,
          model: model,
          reasoning_effort: reasoning_effort,
          request_payload: request_payload
        )
      else
        trace_recorder_class.new(
          task: task,
          purpose: purpose_for_request,
          model: model,
          reasoning_effort: reasoning_effort,
          request_payload: request_payload
        )
      end
    end

    def handle_response(response)
      payload = parsed_payload(response)
      state = payload.fetch("state")
      persist_usage(response)
      task.openai_response_id = response_value(response, "id") if task.respond_to?(:openai_response_id=)

      case state
      when "source_understood"
        set_source_understanding!(payload.fetch("source_understanding"))
        mark_status!(payload["recommended_next_state"] == "needs_input" ? "needs_input" : "drafting")
      when "needs_input"
        create_question_batch!(payload)
        mark_status!("needs_input")
      when "draft_ready"
        task.update!(draft_ros_json: payload.fetch("draft_ros"), status: "drafting")
      when "ready_for_review"
        task.update!(
          plan_json: payload,
          current_plan_version: task.current_plan_version.to_i + 1,
          status: "ready_for_review"
        )
      else
        raise ArgumentError, "Unsupported agent state #{state.inspect}"
      end

      append_event!(state, payload["summary"])
      payload
    end

    def create_question_batch!(payload)
      next_position = task.question_batches.maximum(:position).to_i + 1
      task.question_batches.create!(
        position: next_position,
        summary: payload["summary"],
        questions_json: payload.fetch("questions"),
        status: "open"
      )
    end

    def set_source_understanding!(payload)
      if task.respond_to?(:source_understanding_json=)
        task.update!(source_understanding_json: payload)
      else
        task.update!(latest_source_understanding_json: payload)
      end
    end

    def persist_usage(response)
      usage = response_value(response, "usage") || {}
      if task.respond_to?(:usage_json=)
        task.usage_json = usage
      elsif task.respond_to?(:usage_summary_json=)
        task.usage_summary_json = usage
      end
    end

    def parsed_payload(response)
      content = Array(response_value(response, "output")).flat_map { |entry| response_value(entry, "content") }
      parsed = content.filter_map { |entry| response_value(entry, "parsed") }.first
      parsed || JSON.parse(content.filter_map { |entry| response_value(entry, "text") }.first.to_s)
    end

    def mark_status!(status)
      task.update!(status: status)
    end

    def mark_failure!(error)
      attrs = { status: "failed" }
      attrs[:last_error_json] = { class: error.class.name, message: error.message } if task.respond_to?(:last_error_json=)
      task.update!(attrs)
      task.error_message = error.message if task.respond_to?(:error_message=)
      append_event!("failed", error.message)
    end

    def append_event!(event_type, message = nil)
      return unless task.respond_to?(:append_event!)

      task.append_event!(
        event_type: event_type,
        message: message,
        payload: {}
      )
    end

    def response_value(object, key)
      if object.respond_to?(:[])
        object[key] || object[key.to_sym]
      elsif object.respond_to?(key)
        object.public_send(key)
      end
    end

    def model
      task.respond_to?(:model) && task.model.present? ? task.model : MODEL
    end

    def reasoning_effort
      task.respond_to?(:reasoning_effort) && task.reasoning_effort.present? ? task.reasoning_effort : REASONING_EFFORT
    end

    def purpose_for_request
      "source_understanding"
    end
  end
end
