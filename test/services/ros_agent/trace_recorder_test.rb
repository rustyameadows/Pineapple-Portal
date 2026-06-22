require "test_helper"

module RosAgent
  class TraceRecorderTest < ActiveSupport::TestCase
    FakeTask = Struct.new(:llm_calls, keyword_init: true)

    class FakeLlmCallsAssociation
      attr_reader :created_attributes

      def initialize(record:, maximum_attempt: nil)
        @record = record
        @maximum_attempt = maximum_attempt
      end

      def maximum(column_name)
        return @maximum_attempt if column_name.to_sym == :attempt

        nil
      end

      def create!(attributes)
        @created_attributes = attributes
        @record
      end
    end

    class FakeCallRecord
      attr_reader :completed_attributes, :failed_attributes, :updated_attributes

      def complete!(**attributes)
        @completed_attributes = attributes
      end

      def fail!(**attributes)
        @failed_attributes = attributes
      end

      def update!(attributes)
        @updated_attributes = attributes
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

    test "creates a started call with redacted request details" do
      record = FakeCallRecord.new
      task = FakeTask.new(llm_calls: FakeLlmCallsAssociation.new(record: record, maximum_attempt: 2))

      recorder = TraceRecorder.new(
        task: task,
        purpose: "source_understanding",
        model: "gpt-5.5",
        reasoning_effort: "high",
        schema_name: "source_understanding",
        schema_version: "1",
        request_payload: {
          model: "gpt-5.5",
          api_key: "super-secret",
          headers: { Authorization: "Bearer sk-secret-token" },
          input: [
            { type: "input_file", file_id: "file_123" }
          ]
        },
        started_at: Time.zone.parse("2026-06-22 12:00:00")
      )

      recorder.start!

      created = task.llm_calls.created_attributes

      assert_equal "source_understanding", created[:purpose]
      assert_equal "gpt-5.5", created[:model]
      assert_equal "high", created[:reasoning_effort]
      assert_equal "source_understanding", created[:schema_name]
      assert_equal "1", created[:schema_version]
      assert_equal 3, created[:attempt]
      assert_equal "[REDACTED]", created.dig(:request_json, "api_key")
      assert_equal "Bearer [REDACTED]", created.dig(:request_json, "headers", "Authorization")
      assert_equal "file_123", created.dig(:request_json, "input", 0, "file_id")
    end

    test "records successful calls with response metadata and usage" do
      record = FakeCallRecord.new
      task = FakeTask.new(llm_calls: FakeLlmCallsAssociation.new(record: record))

      recorder = TraceRecorder.new(
        task: task,
        purpose: "draft",
        model: "gpt-5.5",
        reasoning_effort: "high",
        request_payload: { model: "gpt-5.5" },
        started_at: Time.zone.parse("2026-06-22 12:00:00")
      )

      recorder.start!
      recorder.complete!(
        response: {
          "id" => "resp_123",
          "request_id" => "req_123",
          "trace_id" => "trace_123",
          "usage" => { "input_tokens" => 1200, "output_tokens" => 450 },
          "headers" => { "authorization" => "Bearer sk-secret-token" }
        },
        completed_at: Time.zone.parse("2026-06-22 12:00:03.250")
      )

      completed = record.completed_attributes

      assert_equal "resp_123", completed[:openai_response_id]
      assert_equal "req_123", completed[:openai_request_id]
      assert_equal "trace_123", completed[:openai_trace_id]
      assert_equal 3250, completed[:duration_ms]
      assert_equal({ "input_tokens" => 1200, "output_tokens" => 450 }, completed[:usage_json])
      assert_equal "Bearer [REDACTED]", completed.dig(:response_json, "headers", "authorization")
    end

    test "records successful calls from SDK responses that require symbol lookups" do
      record = FakeCallRecord.new
      task = FakeTask.new(llm_calls: FakeLlmCallsAssociation.new(record: record))

      recorder = TraceRecorder.new(
        task: task,
        purpose: "file_upload",
        model: "openai-files",
        request_payload: { purpose: "user_data" },
        started_at: Time.zone.parse("2026-06-22 12:00:00")
      )

      recorder.start!
      recorder.complete!(
        response: SymbolOnlyResponse.new(
          id: "file_123",
          request_id: "req_123",
          usage: { input_tokens: 12, output_tokens: 3 },
          headers: { authorization: "Bearer sk-secret-token" }
        ),
        completed_at: Time.zone.parse("2026-06-22 12:00:01")
      )

      completed = record.completed_attributes

      assert_equal "file_123", completed[:openai_response_id]
      assert_equal "req_123", completed[:openai_request_id]
      assert_equal({ "input_tokens" => 12, "output_tokens" => 3 }, completed[:usage_json])
      assert_equal "file_123", completed.dig(:response_json, "id")
      assert_equal "Bearer [REDACTED]", completed.dig(:response_json, "headers", "authorization")
    end

    test "records failures with redacted error details and retryability" do
      record = FakeCallRecord.new
      task = FakeTask.new(llm_calls: FakeLlmCallsAssociation.new(record: record))
      error = Timeout::Error.new("Bearer sk-secret-token timed out")

      recorder = TraceRecorder.new(
        task: task,
        purpose: "final_plan",
        model: "gpt-5.5",
        reasoning_effort: "high",
        request_payload: {
          OPENAI_API_KEY: "secret-key",
          nested: { authorization: "Bearer sk-secret-token" }
        },
        started_at: Time.zone.parse("2026-06-22 12:00:00")
      )

      recorder.start!
      recorder.fail!(
        error: error,
        response: {
          "error" => {
            "message" => "Bearer sk-secret-token timed out"
          }
        },
        completed_at: Time.zone.parse("2026-06-22 12:00:01.500")
      )

      failed = record.failed_attributes

      assert_equal 1500, failed[:duration_ms]
      assert_equal "Timeout::Error", failed.dig(:error_json, :class)
      assert_equal true, failed.dig(:error_json, :retryable)
      assert_equal "[REDACTED] timed out", failed.dig(:error_json, :message)
      assert_equal "[REDACTED]", task.llm_calls.created_attributes.dig(:request_json, "OPENAI_API_KEY")
      assert_equal "Bearer [REDACTED]", task.llm_calls.created_attributes.dig(:request_json, "nested", "authorization")
      assert_equal "Bearer [REDACTED] timed out", failed.dig(:response_json, "error", "message")
    end
  end
end
