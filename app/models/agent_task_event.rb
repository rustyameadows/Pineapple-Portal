class AgentTaskEvent < ApplicationRecord
  belongs_to :agent_task
  belongs_to :created_by, class_name: "User", optional: true, inverse_of: :agent_task_events

  validates :event_type, presence: true
end
