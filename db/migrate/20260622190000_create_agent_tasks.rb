class CreateAgentTasks < ActiveRecord::Migration[8.0]
  def change
    create_table :agent_tasks do |t|
      t.references :event, null: false, foreign_key: true
      t.references :created_by, null: false, foreign_key: { to_table: :users }
      t.references :approved_by, foreign_key: { to_table: :users }
      t.text :prompt, null: false
      t.string :mode, null: false, default: "build_ros_from_source"
      t.string :status, null: false, default: "draft"
      t.integer :current_plan_version, null: false, default: 0
      t.integer :approved_plan_version
      t.datetime :approved_at
      t.datetime :applied_at
      t.string :latest_openai_trace_id
      t.jsonb :latest_source_understanding_json, null: false, default: {}
      t.jsonb :draft_ros_json, null: false, default: {}
      t.jsonb :plan_json, null: false, default: {}
      t.jsonb :validation_json, null: false, default: {}
      t.jsonb :preview_json, null: false, default: {}
      t.jsonb :trace_summary_json, null: false, default: {}
      t.jsonb :usage_summary_json, null: false, default: {}
      t.jsonb :last_error_json, null: false, default: {}
      t.timestamps
    end

    add_index :agent_tasks, [:event_id, :status]
    add_index :agent_tasks, [:event_id, :created_at]

    create_table :agent_task_artifacts do |t|
      t.references :agent_task, null: false, foreign_key: true
      t.references :document, foreign_key: true
      t.uuid :document_logical_id
      t.string :filename, null: false
      t.string :content_type
      t.integer :size_bytes
      t.string :checksum
      t.string :openai_file_id
      t.string :source_kind, null: false, default: "source_document"
      t.jsonb :source_metadata_json, null: false, default: {}
      t.jsonb :source_warnings_json, null: false, default: {}
      t.integer :position, null: false, default: 1
      t.timestamps
    end

    add_index :agent_task_artifacts, [:agent_task_id, :position]
    add_index :agent_task_artifacts, :openai_file_id

    create_table :agent_task_question_batches do |t|
      t.references :agent_task, null: false, foreign_key: true
      t.integer :position, null: false, default: 1
      t.text :summary
      t.jsonb :questions_json, null: false, default: []
      t.jsonb :answers_json, null: false, default: {}
      t.string :status, null: false, default: "open"
      t.datetime :answered_at
      t.timestamps
    end

    add_index :agent_task_question_batches,
              [:agent_task_id, :position],
              name: "idx_agent_question_batches_on_task_position"

    create_table :agent_task_events do |t|
      t.references :agent_task, null: false, foreign_key: true
      t.string :event_type, null: false
      t.text :message
      t.jsonb :payload_json, null: false, default: {}
      t.references :created_by, foreign_key: { to_table: :users }
      t.timestamps
    end

    add_index :agent_task_events, [:agent_task_id, :created_at]
    add_index :agent_task_events, :event_type

    create_table :agent_task_llm_calls do |t|
      t.references :agent_task, null: false, foreign_key: true
      t.string :purpose, null: false
      t.string :provider, null: false, default: "openai"
      t.string :model, null: false
      t.string :reasoning_effort
      t.string :status, null: false, default: "pending"
      t.string :openai_response_id
      t.string :openai_request_id
      t.string :openai_trace_id
      t.string :schema_name
      t.string :schema_version
      t.integer :attempt, null: false, default: 1
      t.datetime :started_at
      t.datetime :completed_at
      t.integer :duration_ms
      t.jsonb :request_json, null: false, default: {}
      t.jsonb :response_json, null: false, default: {}
      t.jsonb :usage_json, null: false, default: {}
      t.jsonb :error_json, null: false, default: {}
      t.timestamps
    end

    add_index :agent_task_llm_calls, [:agent_task_id, :created_at]
    add_index :agent_task_llm_calls, :openai_response_id
    add_index :agent_task_llm_calls, :openai_trace_id
  end
end
