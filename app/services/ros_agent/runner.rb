module RosAgent
  class Runner
    MODEL = "gpt-5.5".freeze
    REASONING_EFFORT = "high".freeze
    MAX_STEPS = 3

    def initialize(task:,
                   client: OpenaiClient.new,
                   prompt_builder_class: PromptBuilder,
                   source_document_uploader_class: SourceDocumentUploader,
                   source_file_input_builder_class: SourceFileInputBuilder,
                   event_context_class: EventContext,
                   draft_change_plan_builder_class: DraftChangePlanBuilder,
                   trace_recorder_class: TraceRecorder)
      @task = task
      @client = client
      @prompt_builder_class = prompt_builder_class
      @source_document_uploader_class = source_document_uploader_class
      @source_file_input_builder_class = source_file_input_builder_class
      @event_context_class = event_context_class
      @draft_change_plan_builder_class = draft_change_plan_builder_class
      @trace_recorder_class = trace_recorder_class
    end

    def call(options = nil, mode: :initial_run)
      mode = options[:mode] if options.is_a?(Hash) && options.key?(:mode)
      recorder = nil
      model_call_started = false
      model_call_completed = false
      model_call_purpose = nil

      mark_status!(status_for_mode(mode))
      return promote_draft_to_change_plan! if mode.to_sym == :request_final_plan

      upload_source_documents!

      payload = nil
      MAX_STEPS.times do
        request_payload = build_request_payload(mode)
        model_call_purpose = purpose_for_request(mode)
        recorder = trace_recorder_for(request_payload, mode)
        recorder.start!
        model_call_started = true
        model_call_completed = false
        append_event!("model_call_started", "Started #{model_call_purpose.tr("_", " ")} OpenAI call.")

        response = client.responses_create(**request_payload)
        recorder.complete!(response: response)
        model_call_completed = true
        append_event!("model_call_completed", "Completed #{model_call_purpose.tr("_", " ")} OpenAI call.")
        payload = handle_response(response)
        return payload unless continue_after?(payload)
      end

      recorder = nil
      raise ArgumentError, "Agent stopped after source understanding without producing questions or a draft."
    rescue StandardError => e
      recorder&.fail!(error: e, response: {})
      if model_call_started && !model_call_completed
        append_event!("model_call_failed", "#{model_call_purpose.to_s.tr("_", " ")} OpenAI call failed: #{e.message}")
      end
      mark_failure!(e)
      raise
    end

    private

    attr_reader :task, :client, :prompt_builder_class, :source_document_uploader_class, :source_file_input_builder_class, :event_context_class, :draft_change_plan_builder_class, :trace_recorder_class

    def upload_source_documents!
      source_document_uploader_class.new(
        task: task,
        client: client,
        trace_recorder_class: trace_recorder_class
      ).call
    end

    def promote_draft_to_change_plan!
      payload = draft_change_plan_builder_class.new(
        task: task,
        calendar: run_of_show_calendar
      ).call
      validation_result = validate_change_plan!(payload)
      preview = build_change_plan_preview(payload)
      task.update!(
        plan_json: payload,
        validation_json: validation_result.as_json,
        preview_json: preview,
        current_plan_version: task.current_plan_version.to_i + 1,
        status: "ready_for_review"
      )
      append_event!("ready_for_review", payload["summary"])
      payload
    end

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

    def trace_recorder_for(request_payload, mode)
      if trace_recorder_class.respond_to?(:call)
        trace_recorder_class.call(
          task: task,
          purpose: purpose_for_request(mode),
          model: model,
          reasoning_effort: reasoning_effort,
          request_payload: request_payload
        )
      else
        trace_recorder_class.new(
          task: task,
          purpose: purpose_for_request(mode),
          model: model,
          reasoning_effort: reasoning_effort,
          request_payload: request_payload
        )
      end
    end

    def handle_response(response)
      payload = parsed_payload(response)
      state = payload.fetch("state")
      validate_payload!(state, payload)
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
        validation_result = validate_change_plan!(payload)
        preview = build_change_plan_preview(payload)
        task.update!(
          plan_json: payload,
          validation_json: validation_result.as_json,
          preview_json: preview,
          current_plan_version: task.current_plan_version.to_i + 1,
          status: "ready_for_review"
        )
      else
        raise ArgumentError, "Unsupported agent state #{state.inspect}"
      end

      append_event!(state, payload["summary"])
      payload
    end

    def continue_after?(payload)
      payload["state"] == "source_understood"
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
      usage = OpenaiResponse.json_safe(response_value(response, "usage") || {})
      if task.respond_to?(:usage_json=)
        task.usage_json = usage
      elsif task.respond_to?(:usage_summary_json=)
        task.usage_summary_json = usage
      end
    end

    def validate_payload!(state, payload)
      case state
      when "source_understood"
        Schemas::AgentTurnSchema.validate!(payload)
        Schemas::SourceUnderstandingSchema.validate!(payload.fetch("source_understanding"))
      when "needs_input"
        Schemas::AgentTurnSchema.validate!(payload)
        Schemas::QuestionBatchSchema.validate!(payload)
      when "draft_ready"
        Schemas::AgentTurnSchema.validate!(payload)
        Schemas::DraftRosSchema.validate!(payload.fetch("draft_ros"))
      when "ready_for_review"
        Schemas::ChangePlanSchema.validate!(payload)
      else
        raise ArgumentError, "Unsupported agent state #{state.inspect}"
      end
    end

    def validate_change_plan!(payload)
      RosAgent::ChangePlanValidator.new(
        task: task,
        calendar: run_of_show_calendar,
        plan_hash: payload
      ).call
    end

    def build_change_plan_preview(payload)
      RosAgent::ChangePlanPreview.new(
        task: task,
        calendar: run_of_show_calendar,
        plan_hash: payload
      ).call
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
      OpenaiResponse.value(object, key)
    end

    def model
      task.respond_to?(:model) && task.model.present? ? task.model : MODEL
    end

    def reasoning_effort
      task.respond_to?(:reasoning_effort) && task.reasoning_effort.present? ? task.reasoning_effort : REASONING_EFFORT
    end

    def purpose_for_request(mode)
      case mode.to_sym
      when :answer_questions
        "questions"
      when :refine_draft
        "refinement"
      when :request_final_plan
        "final_plan"
      else
        "source_understanding"
      end
    end

    def status_for_mode(mode)
      case mode.to_sym
      when :request_final_plan
        "planning"
      when :refine_draft
        "drafting"
      else
        "analyzing"
      end
    end

    def run_of_show_calendar
      task.event.run_of_show_calendar || task.event.event_calendars.build(
        name: "Run of Show",
        timezone: EventCalendar::DEFAULT_TIMEZONE,
        kind: EventCalendar::KINDS[:master]
      )
    end
  end
end
