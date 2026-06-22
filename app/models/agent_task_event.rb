class AgentTaskEvent < ApplicationRecord
  belongs_to :agent_task
  belongs_to :created_by, class_name: "User", optional: true

  validates :event_type, presence: true
end
