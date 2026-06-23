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

  DEFAULT_MODEL = "gpt-5.5".freeze
  DEFAULT_REASONING_EFFORT = "high".freeze
  MODEL_OPTIONS = [
    ["GPT-5.5", "gpt-5.5"],
    ["GPT-5.4 Mini", "gpt-5.4-mini"]
  ].freeze
  REASONING_EFFORT_OPTIONS = [
    ["None", "none"],
    ["Minimal", "minimal"],
    ["Low", "low"],
    ["Medium", "medium"],
    ["High", "high"],
    ["X-High", "xhigh"]
  ].freeze

  belongs_to :event
  belongs_to :created_by, class_name: "User"
  belongs_to :approved_by, class_name: "User", optional: true

  has_many :artifacts, class_name: "AgentTaskArtifact", dependent: :destroy
  has_many :question_batches, class_name: "AgentTaskQuestionBatch", dependent: :destroy
  has_many :events, class_name: "AgentTaskEvent", dependent: :destroy
  has_many :llm_calls, class_name: "AgentTaskLlmCall", dependent: :destroy

  attribute :status, :string
  attribute :mode, :string
  attribute :model, :string, default: DEFAULT_MODEL
  attribute :reasoning_effort, :string, default: DEFAULT_REASONING_EFFORT

  enum :status, STATUSES, validate: true
  enum :mode, MODES, validate: true

  validates :prompt, presence: true
  validates :model, inclusion: { in: MODEL_OPTIONS.map(&:second) }
  validates :reasoning_effort, inclusion: { in: REASONING_EFFORT_OPTIONS.map(&:second) }
  validates :current_plan_version, numericality: { greater_than_or_equal_to: 0 }

  def ready_to_apply?
    approved? &&
      approved_plan_version.present? &&
      approved_plan_version == current_plan_version &&
      validation_blocking_errors.empty? &&
      (!high_risk_plan? || high_risk_acknowledged?)
  end

  def approvable?
    ready_for_review? && plan_json.present? && validation_blocking_errors.empty?
  end

  def validation_blocking_errors
    json_value(validation_json, "blocking_errors") || []
  end

  def high_risk_plan?
    high_risk_operation_ids.any?
  end

  def high_risk_operation_ids
    Array(json_value(preview_json, "high_risk_operation_ids") || json_value(validation_json, "high_risk_operation_ids")).map(&:to_s)
  end

  def high_risk_acknowledged?
    approval = json_value(validation_json, "approval").to_h
    approval["high_risk_acknowledged"] == true || approval[:high_risk_acknowledged] == true
  end

  def acknowledge_high_risk!(user:)
    update!(
      validation_json: validation_json.to_h.deep_merge(
        "approval" => {
          "high_risk_acknowledged" => true,
          "high_risk_acknowledged_at" => Time.current.iso8601,
          "high_risk_acknowledged_by_id" => user&.id,
          "high_risk_operation_ids" => high_risk_operation_ids
        }
      )
    )
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

  def json_value(source, key)
    hash = source.to_h
    hash[key] || hash[key.to_sym]
  end
end
