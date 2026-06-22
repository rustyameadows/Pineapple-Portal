class AgentTaskLlmCall < ApplicationRecord
  STATUSES = {
    pending: "pending",
    completed: "completed",
    failed: "failed"
  }.freeze

  PURPOSES = {
    source_understanding: "source_understanding",
    questions: "questions",
    draft: "draft",
    refinement: "refinement",
    final_plan: "final_plan",
    retry: "retry",
    summary: "summary"
  }.freeze

  belongs_to :agent_task

  attribute :status, :string
  enum :status, STATUSES, validate: true

  validates :purpose, presence: true
  validates :provider, presence: true
  validates :model, presence: true
  validates :attempt, numericality: { greater_than: 0 }

  def complete!(response_json:, usage_json: {}, openai_response_id: nil, openai_request_id: nil, openai_trace_id: nil, completed_at: Time.current)
    update!(
      status: STATUSES[:completed],
      completed_at: completed_at,
      duration_ms: duration_between(started_at, completed_at),
      response_json: response_json || {},
      usage_json: usage_json || {},
      openai_response_id: openai_response_id,
      openai_request_id: openai_request_id,
      openai_trace_id: openai_trace_id
    )
  end

  def fail!(error_json:, response_json: {}, completed_at: Time.current)
    update!(
      status: STATUSES[:failed],
      completed_at: completed_at,
      duration_ms: duration_between(started_at, completed_at),
      error_json: error_json || {},
      response_json: response_json || {}
    )
  end

  private

  def duration_between(start_time, end_time)
    return unless start_time && end_time

    ((end_time - start_time) * 1000).round
  end
end
