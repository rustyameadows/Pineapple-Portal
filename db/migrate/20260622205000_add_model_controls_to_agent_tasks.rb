class AddModelControlsToAgentTasks < ActiveRecord::Migration[8.0]
  def change
    add_column :agent_tasks, :model, :string, default: "gpt-5.5", null: false
    add_column :agent_tasks, :reasoning_effort, :string, default: "high", null: false
  end
end
