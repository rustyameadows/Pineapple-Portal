module RosAgent
  class RunTaskJob < ApplicationJob
    queue_as :default

    def perform(agent_task_id, mode: :initial_run)
      task = AgentTask.find(agent_task_id)
      Runner.new(task: task).call({ mode: mode.to_sym })
    end
  end
end
