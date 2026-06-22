class AgentTask < ApplicationRecord
  STATUSES = {
    draft: "draft",
    analyzing: "analyzing",
    needs_input: "needs_input",
    drafting: "drafting",
    planning: "planning",
    ready_for_review: "ready_for_review",
    approved: "approved",
    applying: "applying",
    applied: "applied",
    failed: "failed"
  }.freeze

  MODES = {
    build_ros_from_source: "build_ros_from_source",
    clean_up_ros: "clean_up_ros",
    bulk_update_ros: "bulk_update_ros",
    analysis_only: "analysis_only"
  }.freeze

  belongs_to :event
  belongs_to :created_by, class_name: "User"
  belongs_to :approved_by, class_name: "User", optional: true

  has_many :artifacts, class_name: "AgentTaskArtifact", dependent: :destroy
  has_many :question_batches, class_name: "AgentTaskQuestionBatch", dependent: :destroy
  has_many :events, class_name: "AgentTaskEvent", dependent: :destroy
  has_many :llm_calls, class_name: "AgentTaskLlmCall", dependent: :destroy

  attribute :status, :string
  attribute :mode, :string

  enum :status, STATUSES, validate: true
  enum :mode, MODES, validate: true

  validates :prompt, presence: true
  validates :current_plan_version, numericality: { greater_than_or_equal_to: 0 }

  def ready_to_apply?
    approved? &&
      approved_plan_version.present? &&
      approved_plan_version == current_plan_version &&
      blocking_validation_errors.empty?
  end

  def append_event!(event_type:, message: nil, payload: {}, created_by: nil)
    events.create!(
      event_type: event_type,
      message: message,
      payload_json: payload || {},
      created_by: created_by
    )
  end

  private

  def blocking_validation_errors
    validation_json.fetch("blocking_errors", [])
  end
end
