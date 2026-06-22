require "test_helper"

class AgentTaskLlmCallTest < ActiveSupport::TestCase
  test "defaults status to pending" do
    call = AgentTaskLlmCall.new(
      agent_task: agent_tasks(:draft_task),
      purpose: "source_understanding",
      model: "gpt-5.5",
      started_at: 2.seconds.ago
    )

    assert_equal "openai", call.provider
    assert_equal "pending", call.status
    assert_equal 1, call.attempt
  end

  test "complete! stores response snapshots and timing" do
    call = agent_task_llm_calls(:pending_source_understanding)
    completed_at = call.started_at + 3.25.seconds

    call.complete!(
      response_json: {
        id: "resp_123",
        trace: {
          redacted: true
        }
      },
      usage_json: {
        input_tokens: 1200,
        output_tokens: 450
      },
      openai_response_id: "resp_123",
      openai_trace_id: "trace_123",
      completed_at: completed_at
    )

    call.reload

    assert_equal "completed", call.status
    assert_equal "resp_123", call.openai_response_id
    assert_equal "trace_123", call.openai_trace_id
    assert_equal(
      {
        "id" => "resp_123",
        "trace" => { "redacted" => true }
      },
      call.response_json
    )
    assert_equal(
      {
        "input_tokens" => 1200,
        "output_tokens" => 450
      },
      call.usage_json
    )
    assert_equal 3250, call.duration_ms
    assert_in_delta completed_at.to_f, call.completed_at.to_f, 0.001
  end

  test "fail! stores error snapshots and timing" do
    call = agent_task_llm_calls(:pending_source_understanding)
    completed_at = call.started_at + 1.5.seconds

    call.fail!(
      error_json: {
        code: "timeout",
        message: "The provider timed out."
      },
      response_json: {
        status: "error"
      },
      completed_at: completed_at
    )

    call.reload

    assert_equal "failed", call.status
    assert_equal(
      {
        "code" => "timeout",
        "message" => "The provider timed out."
      },
      call.error_json
    )
    assert_equal({ "status" => "error" }, call.response_json)
    assert_equal 1500, call.duration_ms
    assert_in_delta completed_at.to_f, call.completed_at.to_f, 0.001
  end
end
