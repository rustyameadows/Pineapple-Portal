require "test_helper"

class AgentTaskTest < ActiveSupport::TestCase
  test "defaults status to draft" do
    task = AgentTask.new(
      event: events(:one),
      created_by: users(:one),
      prompt: "Adapt this prior event run of show for the current wedding."
    )

    assert_equal "draft", task.status
    assert_equal 0, task.current_plan_version
  end

  test "requires prompt" do
    task = agent_tasks(:draft_task)
    task.prompt = " "

    assert_not task.valid?
    assert_includes task.errors[:prompt], "can't be blank"
  end

  test "destroys dependent records" do
    task = agent_tasks(:draft_task)
    artifact_id = agent_task_artifacts(:source_artifact).id
    question_batch_id = agent_task_question_batches(:open_questions).id
    task_event_id = agent_task_events(:draft_logged).id
    llm_call_id = agent_task_llm_calls(:pending_source_understanding).id

    task.destroy!

    assert_not AgentTaskArtifact.exists?(artifact_id)
    assert_not AgentTaskQuestionBatch.exists?(question_batch_id)
    assert_not AgentTaskEvent.exists?(task_event_id)
    assert_not AgentTaskLlmCall.exists?(llm_call_id)
  end

  test "append_event! creates a task event" do
    task = agent_tasks(:draft_task)

    task_event = task.append_event!(
      event_type: "status_changed",
      message: "Task moved into planning.",
      payload: { from: "draft", to: "planning" },
      created_by: users(:two)
    )

    assert_predicate task_event, :persisted?
    assert_equal task, task_event.agent_task
    assert_equal "status_changed", task_event.event_type
    assert_equal "Task moved into planning.", task_event.message
    assert_equal({ "from" => "draft", "to" => "planning" }, task_event.payload_json)
    assert_equal users(:two), task_event.created_by
  end

  test "ready_to_apply? requires approval for the current plan version" do
    task = agent_tasks(:approved_task)

    assert task.ready_to_apply?

    task.update!(approved_plan_version: task.current_plan_version - 1)

    assert_not task.ready_to_apply?
  end
end
