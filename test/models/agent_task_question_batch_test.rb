require "test_helper"

class AgentTaskQuestionBatchTest < ActiveSupport::TestCase
  test "defaults status to open" do
    batch = AgentTaskQuestionBatch.new(agent_task: agent_tasks(:draft_task))

    assert_equal "open", batch.status
  end

  test "answer! persists answers and timestamps" do
    batch = agent_task_question_batches(:open_questions)
    answered_at = Time.zone.parse("2026-06-22 09:30:00")

    batch.answer!(
      {
        date_mapping: "map_saturday_to_wedding_date",
        scrub_names: true
      },
      answered_at: answered_at
    )

    batch.reload

    assert_equal "answered", batch.status
    assert_equal(
      {
        "date_mapping" => "map_saturday_to_wedding_date",
        "scrub_names" => true
      },
      batch.answers_json
    )
    assert_in_delta answered_at.to_f, batch.answered_at.to_f, 0.001
  end
end
