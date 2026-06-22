require "test_helper"

module RosAgent
  class RunTaskJobTest < ActiveJob::TestCase
    test "loads the task and delegates to the runner" do
      task = Struct.new(:id).new(123)
      runner = Minitest::Mock.new
      created_agent_task_constant = false

      agent_task_class = if defined?(AgentTask)
        AgentTask
      else
        created_agent_task_constant = true
        Object.const_set("AgentTask", Class.new)
      end

      agent_task_class.stub :find, task do
        Runner.stub :new, ->(task:) {
          assert_equal 123, task.id
          runner
        } do
          runner.expect(:call, true, [{ mode: :request_final_plan }])

          RosAgent::RunTaskJob.perform_now(123, mode: :request_final_plan)
        end
      end

      runner.verify
    ensure
      Object.send(:remove_const, :AgentTask) if created_agent_task_constant && defined?(::AgentTask)
    end
  end
end
