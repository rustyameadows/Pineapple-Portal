# ROS Agent Planning Mode Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build an existing-event ROS agent workflow that sends raw source documents to `gpt-5.5`, stores the model's source understanding and draft ROS scratchpad, asks structured planning questions, generates a validated ROS change plan, previews changes, and applies only after planner approval.

**Architecture:** Rails owns workflow state, file packaging, local API trace snapshots, validation, preview, approval, and database writes. OpenAI Responses API produces model-led source understanding, draft scratchpads, question batches, refinement updates, and final ROS change plans. Existing calendar services remain the write path for ROS records.

**Tech Stack:** Rails 8, ActiveJob/Solid Queue, PostgreSQL JSONB, ERB/Hotwire/Stimulus, official OpenAI Ruby SDK, existing `Event`, `EventCalendar`, `CalendarItem`, `Document`, `Attachment`, and calendar command services.

---

## Scope And Decisions

- This plan implements the existing-event ROS planning mode only.
- New event creation remains a separate future workflow.
- All ROS writes require explicit planner approval.
- The model never receives a direct low-level write tool.
- Raw source documents go to `gpt-5.5` for understanding; Rails does not implement business parsers for arbitrary source ROS formats.
- Rails may collect lightweight file metadata and package OpenAI file/image inputs, but model output is the source understanding.
- The workflow stores both a model-generated source understanding and a model-generated draft ROS scratchpad before final plan approval.
- Local API call tracing is part of the foundation, not later polish.
- OpenAI-hosted Traces dashboard support is optional and should be revisited only if adopting Agents SDK or a supported tracing integration becomes worthwhile.
- The first planning model is `gpt-5.5`.
- Migrations must be newly generated. Do not edit an existing migration file.
- After migrations are ready, ask the maintainer to run them.

## Proposed File Structure

### New Files

- `app/models/agent_task.rb`: workflow root record scoped to an event and user.
- `app/models/agent_task_artifact.rb`: source document, OpenAI file reference, and source evidence metadata record.
- `app/models/agent_task_question_batch.rb`: structured planning questions and answers.
- `app/models/agent_task_event.rb`: append-only task history.
- `app/models/agent_task_llm_call.rb`: durable API call trace snapshot for every OpenAI call.
- `app/services/ros_agent/event_context.rb`: serializes safe event, ROS, tag, view, and team context for the agent.
- `app/services/ros_agent/source_file_input_builder.rb`: packages uploaded documents for OpenAI file/image inputs.
- `app/services/ros_agent/trace_recorder.rb`: records request/response snapshots, usage, timings, and errors.
- `app/services/ros_agent/schemas/source_understanding_schema.rb`: schema and validator for model-generated source understanding.
- `app/services/ros_agent/schemas/draft_ros_schema.rb`: schema and validator for model-generated draft scratchpads.
- `app/services/ros_agent/schemas/question_batch_schema.rb`: schema and validator for Q&A batch output.
- `app/services/ros_agent/schemas/change_plan_schema.rb`: schema and validator for ROS change plan output.
- `app/services/ros_agent/prompt_builder.rb`: builds OpenAI instructions and input payloads.
- `app/services/ros_agent/runner.rb`: calls Responses API and persists task results.
- `app/services/ros_agent/change_plan_validator.rb`: validates plan semantics against the event calendar.
- `app/services/ros_agent/change_plan_preview.rb`: converts a valid plan into planner-facing before/after preview JSON.
- `app/services/ros_agent/change_plan_applier.rb`: applies an approved plan transactionally.
- `app/jobs/ros_agent/run_task_job.rb`: background job for source understanding, drafting, refinement, and planning.
- `app/controllers/events/ros_agent_tasks_controller.rb`: planner-facing task CRUD and workflow actions.
- `app/views/events/ros_agent_tasks/index.html.erb`: task list for an event.
- `app/views/events/ros_agent_tasks/new.html.erb`: prompt and source upload/selection form.
- `app/views/events/ros_agent_tasks/show.html.erb`: task detail, Q&A, preview, and apply UI.
- `app/views/events/ros_agent_tasks/_question_batch.html.erb`: structured question form.
- `app/views/events/ros_agent_tasks/_preview.html.erb`: plan preview partial.
- `app/javascript/controllers/ros_agent_task_controller.js`: small UI behavior for recommended answers and high-risk acknowledgement.
- `test/models/agent_task_test.rb`
- `test/models/agent_task_question_batch_test.rb`
- `test/models/agent_task_llm_call_test.rb`
- `test/services/ros_agent/source_file_input_builder_test.rb`
- `test/services/ros_agent/trace_recorder_test.rb`
- `test/services/ros_agent/source_understanding_schema_test.rb`
- `test/services/ros_agent/draft_ros_schema_test.rb`
- `test/services/ros_agent/change_plan_validator_test.rb`
- `test/services/ros_agent/change_plan_preview_test.rb`
- `test/services/ros_agent/change_plan_applier_test.rb`
- `test/services/ros_agent/runner_test.rb`
- `test/jobs/ros_agent/run_task_job_test.rb`
- `test/controllers/events/ros_agent_tasks_controller_test.rb`
- `test/fixtures/files/millar_run_of_show.csv`

### Modified Files

- `Gemfile`: add official OpenAI Ruby SDK.
- `config/routes.rb`: add event-scoped ROS agent task routes.
- `app/models/event.rb`: add agent task association.
- `app/models/user.rb`: add created/approved agent task associations.
- `app/javascript/controllers/index.js`: register the ROS agent task controller.
- `app/views/events/calendars/show.html.erb`: add entry point to Agent Assist.
- `app/views/events/calendar_views/show.html.erb`: optional entry point from derived views.
- `config/credentials.yml.enc` or deployment environment: provide `OPENAI_API_KEY` at runtime.

## Data Model

### Task 1: Add Agent Task Tables

**Files:**
- Create: `db/migrate/<timestamp>_create_agent_tasks.rb`
- Create: `app/models/agent_task.rb`
- Create: `app/models/agent_task_artifact.rb`
- Create: `app/models/agent_task_question_batch.rb`
- Create: `app/models/agent_task_event.rb`
- Create: `app/models/agent_task_llm_call.rb`
- Modify: `app/models/event.rb`
- Modify: `app/models/user.rb`
- Test: `test/models/agent_task_test.rb`
- Test: `test/models/agent_task_question_batch_test.rb`
- Test: `test/models/agent_task_llm_call_test.rb`

- [ ] **Step 1: Generate a new migration**

Run:

```bash
bin/rails generate migration CreateAgentTasks
```

Expected: Rails creates a new migration file. Do not edit any existing migration.

- [ ] **Step 2: Fill the migration with the task tables**

Use the new migration to create:

```ruby
create_table :agent_tasks do |t|
  t.references :event, null: false, foreign_key: true
  t.references :created_by, null: false, foreign_key: { to_table: :users }
  t.references :approved_by, foreign_key: { to_table: :users }
  t.string :workflow, null: false, default: "ros_planning"
  t.string :status, null: false, default: "draft"
  t.text :prompt, null: false
  t.string :model, null: false, default: "gpt-5.5"
  t.string :reasoning_effort, null: false, default: "high"
  t.string :openai_response_id
  t.string :latest_openai_trace_id
  t.jsonb :source_understanding_json, null: false, default: {}
  t.jsonb :draft_ros_json, null: false, default: {}
  t.jsonb :plan_json, null: false, default: {}
  t.jsonb :validation_json, null: false, default: {}
  t.jsonb :preview_json, null: false, default: {}
  t.jsonb :usage_json, null: false, default: {}
  t.jsonb :trace_summary_json, null: false, default: {}
  t.integer :approved_plan_version
  t.integer :current_plan_version, null: false, default: 0
  t.datetime :approved_at
  t.datetime :applied_at
  t.datetime :failed_at
  t.text :error_message
  t.timestamps
end

add_index :agent_tasks, [:event_id, :status]
add_index :agent_tasks, [:event_id, :created_at]

create_table :agent_task_artifacts do |t|
  t.references :agent_task, null: false, foreign_key: true
  t.references :document, foreign_key: true
  t.string :document_logical_id
  t.string :filename, null: false
  t.string :content_type
  t.bigint :size_bytes
  t.string :checksum
  t.string :openai_file_id
  t.string :source_kind, null: false, default: "uploaded_source"
  t.integer :position, null: false, default: 1
  t.jsonb :source_metadata_json, null: false, default: {}
  t.jsonb :source_warnings_json, null: false, default: []
  t.timestamps
end

add_index :agent_task_artifacts, [:agent_task_id, :position]

create_table :agent_task_question_batches do |t|
  t.references :agent_task, null: false, foreign_key: true
  t.string :status, null: false, default: "open"
  t.integer :position, null: false, default: 1
  t.jsonb :questions_json, null: false, default: []
  t.jsonb :answers_json, null: false, default: {}
  t.datetime :answered_at
  t.timestamps
end

add_index :agent_task_question_batches, [:agent_task_id, :position], name: "idx_agent_question_batches_on_task_position"

create_table :agent_task_events do |t|
  t.references :agent_task, null: false, foreign_key: true
  t.references :user, foreign_key: true
  t.string :event_type, null: false
  t.jsonb :payload, null: false, default: {}
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
  t.string :status, null: false, default: "started"
  t.string :openai_response_id
  t.string :openai_request_id
  t.string :openai_trace_id
  t.string :schema_name
  t.string :schema_version
  t.integer :attempt, null: false, default: 1
  t.datetime :started_at, null: false
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
```

- [ ] **Step 3: Ask the maintainer to run migrations**

Stop after the migration is in place and ask the maintainer to run:

```bash
bin/rails db:migrate
```

If the sandbox cannot connect to Postgres during later verification, ask the maintainer to loosen approval restrictions so the database can accept connections.

- [ ] **Step 4: Add model enums and associations**

Add `AgentTask` with workflow/status enums:

```ruby
class AgentTask < ApplicationRecord
  WORKFLOWS = {
    ros_planning: "ros_planning"
  }.freeze

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
    failed: "failed",
    canceled: "canceled"
  }.freeze

  belongs_to :event
  belongs_to :created_by, class_name: "User"
  belongs_to :approved_by, class_name: "User", optional: true
  has_many :artifacts, class_name: "AgentTaskArtifact", dependent: :destroy
  has_many :question_batches, class_name: "AgentTaskQuestionBatch", dependent: :destroy
  has_many :task_events, class_name: "AgentTaskEvent", dependent: :destroy
  has_many :llm_calls, class_name: "AgentTaskLlmCall", dependent: :destroy

  enum :workflow, WORKFLOWS, validate: true
  enum :status, STATUSES, validate: true

  validates :prompt, presence: true
  validates :model, presence: true
  validates :reasoning_effort, presence: true
end
```

Add corresponding simple models for artifacts, batches, events, and LLM calls. Add `has_many :agent_tasks, dependent: :destroy` to `Event`. Add created/approved associations to `User`.

- [ ] **Step 5: Add model tests**

Test status validity, required prompt, event scoping, question batch answer persistence, LLM call trace persistence, and dependent destroys.

Run:

```bash
bin/rails test test/models/agent_task_test.rb test/models/agent_task_question_batch_test.rb test/models/agent_task_llm_call_test.rb
```

Expected: tests pass after the models and migration are complete.

## OpenAI Client And Prompting

### Task 2: Add OpenAI SDK And Client Wrapper

**Files:**
- Modify: `Gemfile`
- Create: `app/services/ros_agent/openai_client.rb`
- Test: `test/services/ros_agent/openai_client_test.rb`

- [ ] **Step 1: Add the official OpenAI Ruby SDK**

Add to `Gemfile`:

```ruby
gem "openai"
```

Run:

```bash
bundle install
```

Expected: `Gemfile.lock` includes the OpenAI gem.

- [ ] **Step 2: Add a tiny client wrapper**

Create:

```ruby
module RosAgent
  class OpenaiClient
    def initialize(api_key: ENV.fetch("OPENAI_API_KEY"))
      @client = OpenAI::Client.new(api_key: api_key)
    end

    def responses_create(**payload)
      client.responses.create(**payload)
    end

    def files_create(**payload)
      client.files.create(**payload)
    end

    private

    attr_reader :client
  end
end
```

- [ ] **Step 3: Test missing API key behavior**

Test that initialization raises `KeyError` when `OPENAI_API_KEY` is missing. Do not print secrets in test output.

### Task 3: Add Trace Recorder

**Files:**
- Create: `app/services/ros_agent/trace_recorder.rb`
- Test: `test/services/ros_agent/trace_recorder_test.rb`

- [ ] **Step 1: Create started call records**

`TraceRecorder#start!` should create an `AgentTaskLlmCall` with task, purpose, model, reasoning effort, schema name/version, attempt, started_at, status `started`, and a redacted request snapshot.

- [ ] **Step 2: Complete successful call records**

`TraceRecorder#complete!` should store status `succeeded`, completed_at, duration_ms, OpenAI response ID, request ID if available, trace ID if available, response JSON, and usage JSON.

- [ ] **Step 3: Complete failed call records**

`TraceRecorder#fail!` should store status `failed`, completed_at, duration_ms, and an error JSON payload with class, message, and retryable flag. It must not store API keys or Authorization headers.

- [ ] **Step 4: Test redaction**

Assert request snapshots remove `api_key`, `Authorization`, `OPENAI_API_KEY`, and raw secret-looking bearer tokens while preserving model, schema, prompt version, file IDs, and non-secret metadata.

### Task 4: Build Event Context Serializer

**Files:**
- Create: `app/services/ros_agent/event_context.rb`
- Test: `test/services/ros_agent/event_context_test.rb`

- [ ] **Step 1: Serialize event details**

Include event name, starts_on, ends_on, location, guest_count, attire, style, color_palette, parking details, getting ready details, and planner team names.

- [ ] **Step 2: Serialize current ROS**

Include current master calendar metadata, timezone, tags, views, and ordered items. For each item include ID, title, notes, effective start/end, duration, status, locked, vendor, location, staff, tags, relative anchor, and source-safe display labels.

- [ ] **Step 3: Serialize ROS defaults**

Include `RunOfShowDefaults::TAGS` and `RunOfShowDefaultViews::VIEWS` so the model can classify items into existing taxonomy.

- [ ] **Step 4: Test serialization**

Create fixtures with one event calendar, two anchored items, tags, and a view. Assert the output includes relative timing and tag names without leaking unrelated records.

## Source Document Understanding

### Task 5: Add Source File Input Builder

**Files:**
- Create: `app/services/ros_agent/source_file_input_builder.rb`
- Test: `test/services/ros_agent/source_file_input_builder_test.rb`
- Create: `test/fixtures/files/millar_run_of_show.csv`

- [ ] **Step 1: Add the Millar CSV fixture**

Copy the provided CSV into `test/fixtures/files/millar_run_of_show.csv`. This fixture is source evidence for model tests, not a target for Rails business parsing.

- [ ] **Step 2: Build file input payloads**

`SourceFileInputBuilder` should return OpenAI input content for task artifacts:

```ruby
{
  type: "input_file",
  file_id: artifact.openai_file_id,
  filename: artifact.filename
}
```

For small text-like files without an OpenAI file ID in tests, it may return:

```ruby
{
  type: "input_text",
  text: "Source file: #{artifact.filename}\n\n#{text_preview}"
}
```

The text preview is supporting context only. Do not infer ROS rows locally.

- [ ] **Step 3: Store lightweight metadata**

When attaching artifacts, store filename, content type, size bytes, checksum, OpenAI file ID if uploaded, and simple source metadata. Do not store parsed ROS items from Rails code.

- [ ] **Step 4: Test file input packaging**

Assert CSV, PDF, image, and XLSX artifacts produce file input references when `openai_file_id` is present. Assert the Millar CSV fixture can be attached and referenced without locally converting it to ROS rows.

### Task 6: Define Source Understanding And Draft Scratchpad Schemas

**Files:**
- Create: `app/services/ros_agent/schemas/source_understanding_schema.rb`
- Create: `app/services/ros_agent/schemas/draft_ros_schema.rb`
- Test: `test/services/ros_agent/source_understanding_schema_test.rb`
- Test: `test/services/ros_agent/draft_ros_schema_test.rb`

- [ ] **Step 1: Define source understanding schema**

Require structured fields for source title, source kind, overall read, inferred days, reusable patterns, source-specific details, uncertainties, confidence notes, and source evidence references.

- [ ] **Step 2: Define draft ROS schema**

Require structured fields for target event summary, date mapping, draft days, draft items, assumptions, review flags, refinement notes, and source references. Draft items should include title, timing, duration, notes, location, vendor/staff handling, tags, confidence, and whether planner review is needed.

- [ ] **Step 3: Test schemas**

Assert valid sample source understanding and draft scratchpad payloads pass. Assert missing title, missing draft days, invalid confidence values, and item timing with no title fail.

## Structured Agent Outputs

### Task 7: Define Question Batch Schema

**Files:**
- Create: `app/services/ros_agent/schemas/question_batch_schema.rb`
- Test: `test/services/ros_agent/question_batch_schema_test.rb`

- [ ] **Step 1: Implement schema constants**

Define allowed answer types:

```ruby
ANSWER_TYPES = %w[
  single_choice
  multi_choice
  free_text
  date
  time
  confirm
  mapping
  item_resolution
].freeze
```

- [ ] **Step 2: Validate question batches**

Require `state: "needs_input"`, `summary`, and an array of questions. Each question must have `key`, `label`, `question`, `why_it_matters`, `required`, `answer_type`, and either options or `freeform_allowed`.

- [ ] **Step 3: Test invalid batches**

Assert missing keys, duplicate question keys, invalid answer types, and missing recommended labels produce validation errors.

### Task 8: Define ROS Change Plan Schema

**Files:**
- Create: `app/services/ros_agent/schemas/change_plan_schema.rb`
- Test: `test/services/ros_agent/change_plan_schema_test.rb`

- [ ] **Step 1: Define allowed operations**

Use this first-version operation list:

```ruby
OPERATION_TYPES = %w[
  create_item
  update_item
  delete_item
  reorder_items
  create_tag
  assign_tags
  remove_tags
  set_item_team_members
  set_item_vendor
  set_item_location
  shift_absolute_times
  set_relative_timing
  create_view
  update_view
].freeze
```

- [ ] **Step 2: Validate plan structure**

Require `state: "ready_for_review"`, `summary`, `assumptions`, `operations`, `warnings`, and `review_highlights`. Each operation must have `operation_id`, `operation_type`, `summary`, `risk_level`, `source_refs`, and operation-specific attrs.

- [ ] **Step 3: Test invalid plans**

Assert unknown operation types, duplicate operation IDs, invalid risk levels, and missing summaries are rejected.

## Agent Runner

### Task 9: Build Prompt Builder

**Files:**
- Create: `app/services/ros_agent/prompt_builder.rb`
- Test: `test/services/ros_agent/prompt_builder_test.rb`

- [ ] **Step 1: Build instructions**

Instructions must include:

- Existing-event scope only.
- Raw source documents are primary evidence; do not assume Rails has parsed them.
- Produce source understanding before final app operations.
- Maintain and revise a draft ROS scratchpad over multiple turns.
- Ask questions before planning when answers materially change the ROS.
- Prefer 1 to 3 questions, up to 5 for risky ambiguity.
- Do not ask for facts already present in context.
- Do not output writes directly.
- Return one of: `source_understood`, `needs_input`, `draft_ready`, or `ready_for_review`.
- Mark destructive and large edits as high risk.

- [ ] **Step 2: Build input payload**

Include event context, current ROS context, source file inputs, latest source understanding, latest draft ROS scratchpad, previous question/answer batches, refinement instructions, and the planner prompt.

- [ ] **Step 3: Test prompt contents**

Assert the prompt contains the event ID, event date, default ROS tags, source artifact title, previous answers, source understanding when present, and draft scratchpad when present.

### Task 10: Build Runner And Background Job

**Files:**
- Create: `app/services/ros_agent/runner.rb`
- Create: `app/jobs/ros_agent/run_task_job.rb`
- Test: `test/services/ros_agent/runner_test.rb`
- Test: `test/jobs/ros_agent/run_task_job_test.rb`

- [ ] **Step 1: Runner loads and records context**

Runner should set task status to `analyzing`, collect event context, build source file inputs, include existing source understanding/draft scratchpad when present, and append an `agent_task_event`.

- [ ] **Step 2: Runner calls Responses API**

Call the client with model, reasoning effort, instructions, source file inputs, input payload, and structured output format. Wrap the call with `TraceRecorder` so request/response snapshots, response IDs, usage, timings, and errors are stored. Stub this in tests.

- [ ] **Step 3: Runner persists result**

If result state is `source_understood`, store `source_understanding_json`, set status to `drafting` or `needs_input` based on the result's recommended next state, and log an event.

If result state is `needs_input`, create an `AgentTaskQuestionBatch`, set status `needs_input`, and log an event.

If result state is `draft_ready`, increment the current draft version if implemented, store `draft_ros_json`, set status `drafting`, and log an event.

If result state is `ready_for_review`, increment `current_plan_version`, store `plan_json`, run validation and preview, set status `ready_for_review`, and log an event.

If the API call fails, set status `failed`, store `error_message`, and log an event.

- [ ] **Step 4: Job delegates to runner**

`RosAgent::RunTaskJob` should find the task and call the runner. It should be safe to retry API/network failures without applying writes. Retries should create additional `agent_task_llm_calls` with incremented attempt values.

## Planner Q&A UI

### Task 11: Add Routes And Controller

**Files:**
- Modify: `config/routes.rb`
- Create: `app/controllers/events/ros_agent_tasks_controller.rb`
- Test: `test/controllers/events/ros_agent_tasks_controller_test.rb`

- [ ] **Step 1: Add event-scoped routes**

```ruby
resources :ros_agent_tasks, module: :events, path: "ros-agent", only: %i[index new create show] do
  member do
    patch :answer_questions
    patch :refine_draft
    patch :request_final_plan
    patch :approve
    post :apply
    patch :cancel
  end
end
```

- [ ] **Step 2: Implement controller actions**

Actions:

- `index`: list event agent tasks newest first.
- `new`: prompt form.
- `create`: create draft task and enqueue `RosAgent::RunTaskJob`.
- `show`: render status, question batch, preview, and task history.
- `answer_questions`: save answers to the open question batch and enqueue another run.
- `refine_draft`: save planner refinement instructions against the current scratchpad and enqueue another run.
- `request_final_plan`: ask the runner to turn the latest draft scratchpad into a final change plan.
- `approve`: mark the current plan version approved.
- `apply`: call `ChangePlanApplier` only if approved.
- `cancel`: mark non-applied task canceled.

- [ ] **Step 3: Test controller boundaries**

Assert users cannot answer/refine/apply tasks for another event. Assert final plan request requires a draft scratchpad. Assert apply fails unless status is approved and approved plan version matches current plan version.

### Task 12: Build Q&A Views

**Files:**
- Create: `app/views/events/ros_agent_tasks/index.html.erb`
- Create: `app/views/events/ros_agent_tasks/new.html.erb`
- Create: `app/views/events/ros_agent_tasks/show.html.erb`
- Create: `app/views/events/ros_agent_tasks/_question_batch.html.erb`
- Create: `app/javascript/controllers/ros_agent_task_controller.js`
- Modify: `app/javascript/controllers/index.js`

- [ ] **Step 1: Build new task form**

The form should include prompt text area, source document selection/upload path, and submit button. Keep the copy focused on the workflow, not a marketing explanation.

- [ ] **Step 2: Render question batch**

Render each question with label, why-it-matters text, suggested answer controls, recommended marker, and freeform text input. Include "Use recommended answers" and "Submit answers" controls.

- [ ] **Step 3: Render draft scratchpad**

Show draft days, draft items, source-specific removals, assumptions, review-needed flags, and refinement history. Provide a refinement text box for planner turns such as "make ceremony earlier" or "keep vendor names as placeholders".

- [ ] **Step 4: Add Stimulus behavior**

The controller should fill recommended answers, show/hide freeform fields where appropriate, help submit draft refinement turns, and require high-risk acknowledgement before approval.

- [ ] **Step 5: Test answer submission**

Controller test should submit one suggested answer and one freeform answer, assert the batch is marked answered, and assert the planning job is enqueued.

- [ ] **Step 6: Test draft refinement submission**

Controller test should submit a refinement instruction, assert an event is recorded, and assert the planning job is enqueued without applying calendar changes.

## Plan Validation, Preview, And Apply

### Task 13: Implement Change Plan Validator

**Files:**
- Create: `app/services/ros_agent/change_plan_validator.rb`
- Test: `test/services/ros_agent/change_plan_validator_test.rb`

- [ ] **Step 1: Validate event boundaries**

Reject item IDs, tag IDs, view IDs, and team member IDs that do not belong to the task event.

- [ ] **Step 2: Validate operation semantics**

Reject invalid durations, invalid date/times, unknown planned references, circular relative anchors, missing operation attributes, and event creation attempts.

- [ ] **Step 3: Mark warnings**

Warn for large destructive batches, deleted items with dependent items, missing source evidence, low-confidence model interpretations, and source-specific removals.

- [ ] **Step 4: Test validator**

Create valid and invalid plans. Assert invalid plans return blocking errors and valid plans return no blocking errors.

### Task 14: Implement Change Plan Preview

**Files:**
- Create: `app/services/ros_agent/change_plan_preview.rb`
- Create: `app/views/events/ros_agent_tasks/_preview.html.erb`
- Test: `test/services/ros_agent/change_plan_preview_test.rb`

- [ ] **Step 1: Build preview JSON**

Preview JSON should include counts, creates, updates, deletes, time changes, tag changes, assumptions, warnings, and high-risk operation IDs.

- [ ] **Step 2: Render timeline preview**

Group proposed created/changed items by day in event timezone. Show source row references when available.

- [ ] **Step 3: Test preview counts**

Assert a plan with create, update, and delete operations produces correct counts and before/after rows.

### Task 15: Implement Change Plan Applier

**Files:**
- Create: `app/services/ros_agent/change_plan_applier.rb`
- Test: `test/services/ros_agent/change_plan_applier_test.rb`

- [ ] **Step 1: Guard approval state**

Raise a clear error unless task status is `approved`, approved plan version equals current plan version, and validation has no blocking errors.

- [ ] **Step 2: Apply in a transaction**

Use `ActiveRecord::Base.transaction`. Create/update/delete calendar items, create tags/views, assign tags, set relative timing, reorder items, and run `Calendars::CascadeScheduler` at the end.

- [ ] **Step 3: Reuse existing services where possible**

Use `Calendars::GridBulkUpdater`, `Calendars::Commands::ReorderItems`, `Calendars::Commands::ShiftAbsoluteTimes`, and direct model updates only where there is no existing command service.

- [ ] **Step 4: Record apply result**

Set task status `applied`, store `applied_at`, append an `agent_task_event`, and store applied operation counts.

- [ ] **Step 5: Test rollback**

Create a plan where the second operation is invalid. Assert no first-operation changes remain after failure.

## Navigation And Entry Points

### Task 16: Add Planner Entry Points

**Files:**
- Modify: `app/views/events/calendars/show.html.erb`
- Modify: `app/views/events/calendar_views/show.html.erb`

- [ ] **Step 1: Add Agent Assist CTA**

Add a secondary action near existing calendar actions linking to `new_event_ros_agent_task_path(@event)`.

- [ ] **Step 2: Add task history link**

Add a link to `event_ros_agent_tasks_path(@event)` so planners can revisit prior agent tasks.

- [ ] **Step 3: Test route helpers render**

Add controller or view tests that render the calendar page and assert the Agent Assist link is present for planner users.

## Verification

### Task 17: End-To-End Tests

**Files:**
- Test: `test/controllers/events/ros_agent_tasks_controller_test.rb`
- Test: `test/services/ros_agent/runner_test.rb`
- Test: `test/services/ros_agent/change_plan_applier_test.rb`

- [ ] **Step 1: Test happy path without live OpenAI**

Stub the OpenAI client to return `source_understood`, then `needs_input`, then `draft_ready`, then `ready_for_review`. Submit answers, refine the draft once, request final plan, approve, and apply. Assert calendar items are created.

- [ ] **Step 2: Test no writes before approval**

Run the same flow until `ready_for_review`. Assert `CalendarItem.count` is unchanged before approval/apply.

- [ ] **Step 3: Test provided CSV behavior**

Use the Millar fixture as a raw source artifact with a stubbed `gpt-5.5` source understanding and draft scratchpad. Assert the model-authored output maps Saturday to event date, Friday to day before, preserves important multiline source details in notes where appropriate, and flags source-specific details for scrubbing.

- [ ] **Step 4: Run focused tests**

Run:

```bash
bin/rails test test/models/agent_task_test.rb \
  test/models/agent_task_question_batch_test.rb \
  test/models/agent_task_llm_call_test.rb \
  test/services/ros_agent/source_file_input_builder_test.rb \
  test/services/ros_agent/trace_recorder_test.rb \
  test/services/ros_agent/source_understanding_schema_test.rb \
  test/services/ros_agent/draft_ros_schema_test.rb \
  test/services/ros_agent/change_plan_validator_test.rb \
  test/services/ros_agent/change_plan_preview_test.rb \
  test/services/ros_agent/change_plan_applier_test.rb \
  test/services/ros_agent/runner_test.rb \
  test/jobs/ros_agent/run_task_job_test.rb \
  test/controllers/events/ros_agent_tasks_controller_test.rb
```

Expected: all focused tests pass.

- [ ] **Step 5: Run full test suite**

Run:

```bash
bin/rails test
```

Expected: full test suite passes. If the sandbox cannot connect to Postgres, stop and ask the maintainer to run the command and share output.

## Rollout Checklist

- [ ] `OPENAI_API_KEY` is configured in the target environment.
- [ ] Budget/usage monitoring is enabled for OpenAI API usage.
- [ ] Feature is limited to planner/admin users.
- [ ] All writes require explicit approval.
- [ ] Task history is visible to internal planners.
- [ ] API call trace snapshots are visible to internal planners/developers.
- [ ] Failed tasks preserve error messages and do not apply partial changes.
- [ ] The provided Millar CSV can be sent as raw source evidence to a stubbed `gpt-5.5` source-understanding run.
- [ ] A stubbed `gpt-5.5` source understanding, draft scratchpad, and final plan can produce a preview and apply to the calendar.
