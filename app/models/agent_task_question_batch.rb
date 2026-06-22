class AgentTaskQuestionBatch < ApplicationRecord
  STATUSES = {
    open: "open",
    answered: "answered",
    superseded: "superseded"
  }.freeze

  belongs_to :agent_task

  attribute :status, :string
  enum :status, STATUSES, validate: true

  validates :position, numericality: { greater_than: 0 }

  def answer!(answers, answered_at: Time.current)
    update!(
      answers_json: answers || {},
      answered_at: answered_at,
      status: STATUSES[:answered]
    )
  end
end
