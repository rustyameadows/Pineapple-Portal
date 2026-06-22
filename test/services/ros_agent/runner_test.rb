require "test_helper"

module RosAgent
  class RunnerTest < ActiveSupport::TestCase
    class FakeQuestionBatchAssociation
      attr_reader :created_batches

      def initialize
        @created_batches = []
      end

      def create!(attributes)
        @created_batches << attributes
        attributes
      end

      def maximum(column_name)
        return created_batches.map { |entry| entry[:position] }.compact.max if column_name.to_sym == :position

        nil
      end

      def answered
        []
      end
    end

    class FakeTask
      attr_accessor :id,
                    :event,
                    :prompt,
                    :model,
                    :reasoning_effort,
                    :status,
                    :source_understanding_json,
                    :draft_ros_json,
                    :plan_json,
                    :preview_json,
                    :validation_json,
                    :usage_json,
                    :openai_response_id,
                    :error_message,
                    :current_plan_version

      attr_reader :artifacts, :question_batches, :llm_calls, :appended_events

      def initialize(event:, artifacts: [])
        @id = 77
        @event = event
        @artifacts = artifacts
        @prompt = "Adapt the attached prior event run of show for this wedding."
        @model = "gpt-5.5"
        @reasoning_effort = "high"
        @status = "draft"
        @source_understanding_json = {}
        @draft_ros_json = {}
        @plan_json = {}
        @preview_json = {}
        @validation_json = {}
        @usage_json = {}
        @current_plan_version = 1
        @question_batches = FakeQuestionBatchAssociation.new
        @llm_calls = Object.new
        @appended_events = []
      end

      def update!(attributes)
        attributes.each do |name, value|
          public_send("#{name}=", value)
        end
      end

      def append_event!(**attributes)
        @appended_events << attributes
      end
    end

    class FakeClient
      attr_reader :payloads

      def initialize(response)
        @responses = response.is_a?(Array) ? response.dup : [response]
        @payloads = []
      end

      def responses_create(**payload)
        @payloads << payload
        @responses.shift || raise("No response left")
      end
    end

    class SymbolOnlyResponse
      def initialize(attributes)
        @attributes = attributes
      end

      def [](key)
        raise ArgumentError, %(Expected symbol key for lookup, got "#{key}") unless key.is_a?(Symbol)

        @attributes[key]
      end

      def to_h
        @attributes
      end
    end

    class FakeTraceRecorder
      attr_reader :started, :completed_response, :failed_error, :request_payload

      def initialize(**attributes)
        @request_payload = attributes[:request_payload]
      end

      def start!
        @started = true
      end

      def complete!(response:, **)
        @completed_response = response
      end

      def fail!(error:, **)
        @failed_error = error
      end
    end

    class FakePromptBuilder
      def initialize(task:, mode:, event_context:, source_inputs:)
        @task = task
        @mode = mode
        @event_context = event_context
        @source_inputs = source_inputs
      end

      def build
        {
          instructions: "Prompt for #{@mode}",
          input: [
            {
              role: "user",
              content: [
                { type: "input_text", text: @event_context[:event][:name] },
                *@source_inputs
              ]
            }
          ]
        }
      end
    end

    class FakeSourceFileInputBuilder
      def initialize(task)
        @task = task
      end

      def build
        Array(@task.artifacts)
      end
    end

    class FakeSourceDocumentUploader
      class << self
        attr_accessor :calls
      end
      self.calls = []

      def initialize(task:, client:, trace_recorder_class:)
        @task = task
        @client = client
        @trace_recorder_class = trace_recorder_class
      end

      def call
        self.class.calls << {
          task: @task,
          client: @client,
          trace_recorder_class: @trace_recorder_class
        }
      end
    end

    class FakeEventContext
      def initialize(event)
        @event = event
      end

      def as_json
        { event: { id: @event.id, name: @event.name } }
      end
    end

    setup do
      FakeSourceDocumentUploader.calls = []
    end

    test "stores source understanding and moves into needs_input when recommended" do
      task = FakeTask.new(event: events(:one), artifacts: [{ type: "input_file", file_id: "file_123" }])
      source_response = response_hash(
        payload: {
          "state" => "source_understood",
          "summary" => "Understood the source.",
          "source_understanding" => valid_source_understanding,
          "recommended_next_state" => "needs_input",
          "risk_notes" => []
        }
      )
      question_response = response_hash(
        payload: {
          "state" => "needs_input",
          "summary" => "Need a date mapping decision.",
          "questions" => [
            {
              "key" => "date_mapping",
              "label" => "Date Mapping",
              "question" => "Map Saturday to the wedding date?",
              "why_it_matters" => "This shifts every schedule row.",
              "required" => true,
              "answer_type" => "single_choice",
              "options" => [
                {
                  "value" => "map_saturday_to_wedding_date",
                  "label" => "Map Saturday",
                  "recommended" => true,
                  "description" => "Use the wedding date as the Saturday anchor."
                }
              ],
              "freeform_allowed" => true
            }
          ],
          "assumptions" => [],
          "source_observations" => [],
          "risk_notes" => []
        }
      )
      client = FakeClient.new([source_response, question_response])
      trace_recorder = FakeTraceRecorder.new

      Runner.new(
        task: task,
        client: client,
        prompt_builder_class: FakePromptBuilder,
        source_document_uploader_class: FakeSourceDocumentUploader,
        source_file_input_builder_class: FakeSourceFileInputBuilder,
        event_context_class: FakeEventContext,
        trace_recorder_class: ->(**attributes) {
          trace_recorder.instance_variable_set(:@request_payload, attributes[:request_payload])
          trace_recorder
        }
      ).call(mode: :initial_run)

      assert_equal "needs_input", task.status
      assert_equal 1, FakeSourceDocumentUploader.calls.length
      assert_equal task, FakeSourceDocumentUploader.calls.first[:task]
      assert_equal client, FakeSourceDocumentUploader.calls.first[:client]
      assert_equal valid_source_understanding, task.source_understanding_json
      assert_equal "resp_123", task.openai_response_id
      assert_equal({ "input_tokens" => 100, "output_tokens" => 50 }, task.usage_json)
      assert_equal 1, task.question_batches.created_batches.length
      assert_equal "needs_input", task.appended_events.last[:event_type]
      assert trace_recorder.started
      assert_equal question_response, trace_recorder.completed_response
      assert_equal "gpt-5.5", client.payloads.first[:model]
      assert_equal 2, client.payloads.length
    end

    test "handles OpenAI SDK responses that require symbol lookups" do
      task = FakeTask.new(event: events(:one), artifacts: [{ type: "input_file", file_id: "file_123" }])
      response = response_sdk(
        payload: {
          "state" => "draft_ready",
          "summary" => "Draft ROS is ready for review.",
          "draft_ros" => valid_draft_ros,
          "assumptions" => [],
          "review_notes" => [],
          "suggested_next_questions" => []
        }
      )

      Runner.new(
        task: task,
        client: FakeClient.new(response),
        prompt_builder_class: FakePromptBuilder,
        source_document_uploader_class: FakeSourceDocumentUploader,
        source_file_input_builder_class: FakeSourceFileInputBuilder,
        event_context_class: FakeEventContext,
        trace_recorder_class: ->(**) { FakeTraceRecorder.new }
      ).call(mode: :initial_run)

      assert_equal "drafting", task.status
      assert_equal valid_draft_ros, task.draft_ros_json
      assert_equal "resp_sdk_123", task.openai_response_id
      assert_equal({ "input_tokens" => 100, "output_tokens" => 50 }, task.usage_json)
    end

    test "creates a question batch when the model needs planner input" do
      task = FakeTask.new(event: events(:one))
      response = response_hash(
        payload: {
          "state" => "needs_input",
          "summary" => "Need a date mapping decision.",
          "questions" => [
            {
              "key" => "date_mapping",
              "label" => "Date Mapping",
              "question" => "Map Saturday to the wedding date?",
              "why_it_matters" => "This shifts every schedule row.",
              "required" => true,
              "answer_type" => "single_choice",
              "options" => [
                {
                  "value" => "map_saturday_to_wedding_date",
                  "label" => "Map Saturday",
                  "recommended" => true,
                  "description" => "Use the wedding date as the Saturday anchor."
                }
              ],
              "freeform_allowed" => true
            }
          ],
          "assumptions" => [],
          "source_observations" => [],
          "risk_notes" => []
        }
      )

      Runner.new(
        task: task,
        client: FakeClient.new(response),
        prompt_builder_class: FakePromptBuilder,
        source_document_uploader_class: FakeSourceDocumentUploader,
        source_file_input_builder_class: FakeSourceFileInputBuilder,
        event_context_class: FakeEventContext,
        trace_recorder_class: ->(**) { FakeTraceRecorder.new }
      ).call(mode: :initial_run)

      assert_equal "needs_input", task.status
      assert_equal 1, task.question_batches.created_batches.length
      assert_equal "Need a date mapping decision.", task.question_batches.created_batches.first[:summary]
      assert_equal "needs_input", task.appended_events.last[:event_type]
    end

    test "stores a draft scratchpad for refinement turns" do
      task = FakeTask.new(event: events(:one))
      response = response_hash(
        payload: {
          "state" => "draft_ready",
          "summary" => "Draft ROS is ready for review.",
          "draft_ros" => valid_draft_ros,
          "assumptions" => [],
          "review_notes" => [],
          "suggested_next_questions" => []
        }
      )

      Runner.new(
        task: task,
        client: FakeClient.new(response),
        prompt_builder_class: FakePromptBuilder,
        source_document_uploader_class: FakeSourceDocumentUploader,
        source_file_input_builder_class: FakeSourceFileInputBuilder,
        event_context_class: FakeEventContext,
        trace_recorder_class: ->(**) { FakeTraceRecorder.new }
      ).call(mode: :refine_draft)

      assert_equal "drafting", task.status
      assert_equal valid_draft_ros, task.draft_ros_json
      assert_equal "draft_ready", task.appended_events.last[:event_type]
    end

    test "stores the final change plan and increments plan version" do
      task = FakeTask.new(event: events(:one))
      response = response_hash(payload: valid_change_plan)

      Runner.new(
        task: task,
        client: FakeClient.new(response),
        prompt_builder_class: FakePromptBuilder,
        source_document_uploader_class: FakeSourceDocumentUploader,
        source_file_input_builder_class: FakeSourceFileInputBuilder,
        event_context_class: FakeEventContext,
        trace_recorder_class: ->(**) { FakeTraceRecorder.new }
      ).call(mode: :request_final_plan)

      assert_equal "ready_for_review", task.status
      assert_equal valid_change_plan, task.plan_json
      assert_equal [], task.validation_json[:blocking_errors]
      assert_equal 1, task.preview_json[:create_count]
      assert_equal 2, task.current_plan_version
      assert_equal "ready_for_review", task.appended_events.last[:event_type]
    end

    test "marks the task as failed when the client raises" do
      task = FakeTask.new(event: events(:one))
      trace_recorder = FakeTraceRecorder.new
      client = Object.new
      error = Timeout::Error.new("call timed out")

      client.define_singleton_method(:responses_create) do |**|
        raise error
      end

      raised = assert_raises(Timeout::Error) do
        Runner.new(
          task: task,
          client: client,
          prompt_builder_class: FakePromptBuilder,
          source_document_uploader_class: FakeSourceDocumentUploader,
          source_file_input_builder_class: FakeSourceFileInputBuilder,
          event_context_class: FakeEventContext,
          trace_recorder_class: ->(**attributes) {
            trace_recorder.instance_variable_set(:@request_payload, attributes[:request_payload])
            trace_recorder
          }
        ).call(mode: :initial_run)
      end

      assert_equal error, raised
      assert_equal "failed", task.status
      assert_equal "call timed out", task.error_message
      assert_equal "failed", task.appended_events.last[:event_type]
      assert_equal error, trace_recorder.failed_error
    end

    private

    def response_hash(payload:)
      payload = agent_turn_payload(payload) if %w[source_understood needs_input draft_ready].include?(payload["state"])

      {
        "id" => "resp_123",
        "request_id" => "req_123",
        "usage" => { "input_tokens" => 100, "output_tokens" => 50 },
        "output" => [
          {
            "content" => [
              {
                "type" => "output_text",
                "parsed" => payload
              }
            ]
          }
        ]
      }
    end

    def response_sdk(payload:)
      payload = agent_turn_payload(payload) if %w[source_understood needs_input draft_ready].include?(payload["state"])

      SymbolOnlyResponse.new(
        id: "resp_sdk_123",
        request_id: "req_sdk_123",
        usage: { input_tokens: 100, output_tokens: 50 },
        output: [
          SymbolOnlyResponse.new(
            content: [
              SymbolOnlyResponse.new(
                type: "output_text",
                parsed: payload
              )
            ]
          )
        ]
      )
    end

    def agent_turn_payload(payload)
      {
        "source_understanding" => nil,
        "recommended_next_state" => nil,
        "questions" => [],
        "draft_ros" => nil,
        "assumptions" => [],
        "source_observations" => [],
        "risk_notes" => [],
        "review_notes" => [],
        "suggested_next_questions" => []
      }.merge(payload)
    end

    def valid_source_understanding
      {
        "source_title" => "Shared MOS_Millar Event - Run of Show.csv",
        "source_kind" => "prior_event_ros",
        "overall_read" => "Entertainment-heavy private event across two days.",
        "inferred_days" => [
          {
            "source_label" => "Friday, June 13",
            "role" => "day_before_event",
            "confidence" => "high",
            "notes" => "Production setup day."
          }
        ],
        "reusable_patterns" => ["crew call"],
        "source_specific_details" => [
          {
            "detail" => "Millar",
            "recommended_action" => "remove_or_replace",
            "reason" => "Source client name."
          }
        ],
        "uncertainties" => [],
        "confidence_notes" => [],
        "source_evidence_refs" => []
      }
    end

    def valid_draft_ros
      {
        "target_event_summary" => "Wedding weekend with a production-heavy Saturday.",
        "date_mapping" => { "source_days" => [{ "source_label" => "Saturday, June 14", "target_date" => "2025-10-01" }] },
        "draft_days" => [{ "label" => "Wedding Day", "date" => "2025-10-01" }],
        "draft_items" => [
          {
            "title" => "Crew Call",
            "day_label" => "Wedding Day",
            "timing" => { "kind" => "absolute", "starts_at" => "2025-10-01T08:00:00Z" },
            "duration_minutes" => 60,
            "notes" => "Production setup.",
            "location" => "Grand Ballroom",
            "vendor_handling" => "placeholder",
            "staff_handling" => "map_to_event_team",
            "tags" => ["Production"],
            "confidence" => "high",
            "planner_review_needed" => false,
            "source_refs" => []
          }
        ],
        "assumptions" => [],
        "review_flags" => [],
        "refinement_notes" => [],
        "source_references" => []
      }
    end

    def valid_change_plan
      {
        "state" => "ready_for_review",
        "summary" => "Create a production-heavy wedding day ROS draft.",
        "assumptions" => ["Saturday maps to the event date."],
        "operations" => [
          {
            "operation_id" => "op_1",
            "operation_type" => "create_item",
            "summary" => "Create crew call row.",
            "risk_level" => "low",
            "source_refs" => [{ "artifact" => "millar_sample.csv", "locator" => "Saturday row 4" }],
            "item_attributes" => {
              "title" => "Crew Call",
              "starts_at" => "2025-10-01T08:00:00Z"
            }
          }
        ],
        "warnings" => [],
        "review_highlights" => []
      }
    end
  end
end
