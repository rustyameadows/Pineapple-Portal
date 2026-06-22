# ROS Agent Planning Mode Product Spec

Date: 2026-06-17
Last updated: 2026-06-22

## Summary

Build an agent-assisted planning mode for Run of Show (ROS) work inside an existing event. The feature helps planners transform source material, such as a prior event spreadsheet, photo of a schedule, PDF, or notes, into a detailed ROS draft and final change plan. The model, not Rails parsing code, is responsible for understanding weird source event schemas and translating them into Pineapple's ROS style. Rails stores the raw documents, model-generated source understanding, draft scratchpad, questions, plan, trace snapshots, validation, preview, and final apply result.

The agent does not directly mutate event data while reasoning. It analyzes the current event, source documents, and prompt; asks a structured batch of implementation questions when needed; creates and refines a draft ROS scratchpad; generates a validated change plan; shows a planner-facing preview; and applies changes only after explicit approval.

New event creation is intentionally out of scope for this feature. A future new-event bootstrapper can create or prepare the event first, then hand off to this ROS agent workflow.

## Product Goals

- Help planners adapt real prior-event schedules into a high-quality ROS for an existing event.
- Use high-reasoning `gpt-5.5` for the highest-value work: source document understanding, event-specific scrubbing, Pineapple-style translation, planning questions, first drafts, and major refinements.
- Support conversational planning with structured Q&A batches, recommended answers, and freeform overrides.
- Let the agent reason deeply with `gpt-5.5`, while Rails owns validation, previews, permissions, and database writes.
- Preserve user trust by making every major edit reviewable before it is applied.
- Capture a durable task history and API trace snapshots so planners can understand what happened and developers can debug agent behavior.
- Reuse the existing Rails calendar model, calendar item services, default ROS tags, document storage, and background job patterns.

## Non-Goals

- Do not create new events in this flow.
- Do not let the model directly create, update, or delete records through low-level write tools.
- Do not build deterministic Rails business parsers that try to infer arbitrary source event schemas, date logic, vendor meaning, or scrubbed wedding structure.
- Do not require embeddings, vector search, or long-term semantic memory for the first version.
- Do not replace the existing manual ROS editor, import flow, or bulk edit UI.
- Do not expose this flow to clients in the client portal for the first version.
- Do not attempt fully autonomous edits without planner approval.

## Primary Users

- Planner or admin user working inside an existing event.
- Secondary user: developer/support person reviewing task history, prompts, source understanding, draft scratchpads, API call snapshots, plans, and failures.

## Primary Use Case

The planner opens an existing wedding event with basic details already present, such as couple name, wedding date, location, venue zones, planner team, and current settings. They upload a spreadsheet from a previous event and prompt:

> Attached is a spreadsheet for a previous event. I need to adapt this for this wedding. Use it as the template for the ROS. Shift the dates to align with this event. Make items event-relative as appropriate. Remove info/details specific to the old event.

The agent reads the event and raw source document directly. If the event date is missing or the source has ambiguous day mapping, duplicate entries, event-specific vendor details, or missing ceremony anchors, the agent asks structured questions first. Once questions are answered, the agent creates a draft ROS scratchpad that the planner can refine in turns. When the planner is ready, the agent produces a final ROS change plan and preview. The planner approves, and Rails applies the plan.

## Scope

### Included In Version 1

- Existing-event ROS workflows only.
- Prompt plus one or more uploaded source artifacts.
- Raw CSV/PDF/image/document/spreadsheet inputs sent to OpenAI for model-led source understanding.
- Lightweight file packaging and metadata extraction only; no Rails business parser for source ROS meaning.
- Model-generated source understanding stored in the task.
- Model-generated draft ROS scratchpad that can be refined over multiple turns before final apply.
- Agent Q&A batches with suggested answers and freeform answers.
- Proposed create, update, delete, reorder, tag, and timing changes for ROS items.
- Validation and preview before apply.
- Explicit approval before writes.
- Task history, task events, and first-class API call trace snapshots.
- Background processing for slow agent runs.
- `gpt-5.5` as the default planning model.

### Later Follow-Ups

- New event bootstrapper.
- Multi-agent specialist workflows.
- Reusable learned templates generated from successful tasks.
- Embeddings or semantic retrieval across historical events.
- Client-facing agent interactions.
- Automatic application of very low-risk changes.
- Fine-grained per-line accept/reject in the preview.

## Existing App Context

The app already has strong ROS primitives:

- `Event` stores event settings such as name, starts_on, ends_on, location, guest count, style, color palette, policies, and planning details.
- `EventCalendar` represents the master ROS calendar.
- `CalendarItem` supports title, notes, duration, starts_at, relative anchors, relative offsets, locked state, vendor, location, status, guest count, transportation notes, tags, and team members.
- `Calendars::ImportProjection` and `Calendars::Commands::ImportItems` already handle shifting an existing event timeline by anchor date and preserving relative anchors where possible.
- `Calendars::GridBulkUpdater` already supports bulk status, tags, vendor, location, time label, team member, and delete operations.
- `Calendars::CascadeScheduler` recomputes relative item start times.
- `RunOfShowDefaults` and `RunOfShowDefaultViews` provide useful default tags and filtered views.
- `Document` and `Attachment` already represent uploaded event files.

The ROS agent should sit above these primitives. It should translate messy human/source input into domain operations, not bypass the domain model.

## Experience Design

### Entry Point

Add an "Agent Assist" entry point from the existing event ROS area. The page should make clear that this agent works on the current event only. The planner can:

- Enter a natural-language request.
- Attach existing event documents or upload new files.
- Choose an optional mode:
  - Build ROS from source document.
  - Clean up current ROS.
  - Bulk update current ROS.
  - Ask for analysis only.

The first version can default to "Build ROS from source document" when files are attached.

### Task States

The task moves through these states:

- `draft`: planner is composing prompt and selecting files.
- `analyzing`: agent is reading raw source documents, event context, and current ROS context.
- `needs_input`: agent returned a Q&A batch.
- `drafting`: agent is creating or revising the draft ROS scratchpad.
- `planning`: agent is turning the latest scratchpad into a final change plan.
- `ready_for_review`: plan passed validation and preview is ready.
- `approved`: planner approved the plan.
- `applying`: Rails is applying the approved plan.
- `applied`: changes were applied.
- `failed`: file handling, source understanding, drafting, planning, validation, or apply failed.
- `canceled`: planner canceled before apply.

### Q&A Planning Mode

The agent may ask one or more questions in a batch. A batch should feel similar to Codex plan mode: each question has a short label, a clear prompt, recommended suggested answers, and a freeform entry. The user can answer each question, accept recommended answers, or provide custom guidance.

Question batches are not approval to edit. They only provide planning constraints. The plan still requires separate review and approval.

### Question Batch Rules

The agent should ask questions only when the answer materially changes the ROS plan. It should not ask for information already present in the event, source docs, prior answers, or current task context.

Preferred batch size:

- 1 to 3 questions for normal ambiguity.
- Up to 5 questions when proceeding without answers would create a poor or risky ROS.

Each question must include:

- Stable key.
- Short label.
- Question text.
- Why it matters.
- Whether the question is required.
- Suggested answers, with one recommended answer when appropriate.
- Freeform option unless the answer must be constrained.

### Example Question Batch

```json
{
  "state": "needs_input",
  "summary": "I can adapt the attached prior-event ROS, but a few planning choices will materially change the result.",
  "questions": [
    {
      "key": "date_mapping",
      "label": "Date Mapping",
      "question": "Should the source Saturday timeline map to this event's wedding date?",
      "why_it_matters": "This determines how every item date shifts, including the Friday setup row.",
      "required": true,
      "answer_type": "single_choice",
      "options": [
        {
          "value": "map_saturday_to_wedding_date",
          "label": "Map Saturday to wedding date",
          "recommended": true,
          "description": "Use the event wedding date as the anchor and move source Friday items to the day before."
        },
        {
          "value": "keep_source_dates",
          "label": "Keep source dates",
          "description": "Import dates as written in the source document."
        }
      ],
      "freeform_allowed": true
    }
  ],
  "assumptions": [
    "Remove source-specific client names unless explicitly preserved.",
    "Keep reusable production structure when it appears useful for this wedding."
  ]
}
```

### Supported Question Types

- `single_choice`: choose one option.
- `multi_choice`: choose multiple options.
- `free_text`: write guidance.
- `date`: provide a date.
- `time`: provide a time.
- `confirm`: yes/no with recommended default.
- `mapping`: map source values to event values, such as source day to target day.
- `item_resolution`: decide whether duplicate or overlapping source rows should be merged, kept, or removed.

### Common ROS Questions

- Date mapping: map source Saturday to the wedding date, Friday to day before, or custom.
- Event-specific details: remove, preserve, or convert names/details into placeholders.
- Vendors and performers: preserve names, convert to placeholders, map to existing event vendors, or remove.
- Location names: keep as zones, map to existing locations, or mark as "To confirm".
- Staff names: preserve, remove, map to event team members, or store as additional team members.
- Missing wedding anchors: add ceremony/reception placeholders, use source rows only, or ask planner to provide ceremony timing.
- Duplicates and overlaps: keep separate, merge obvious duplicates, or flag for manual review.
- Relative timing: anchor items to ceremony, guest arrival, cocktail hour, dinner, or performance start when appropriate.

## Source Document Understanding

### Principle

Do not build a Rails parser that tries to understand arbitrary prior-event schedules. The value of the feature is that `gpt-5.5` can read odd spreadsheet layouts, photos, PDFs, and inconsistent planner formats, infer the event logic, scrub one-off details, and translate the result into Pineapple's ROS style. Rails should package and persist files, but the model should perform the business understanding.

### Raw Document Inputs

The first implementation should send the source document itself to OpenAI using file and image inputs. CSV, XLS, XLSX, PDFs, rich documents, and images should all be treated as source evidence for the high-reasoning model. Rails may store lightweight metadata such as filename, content type, size, page count, checksum, and uploaded document ID, but it should not convert the file into final ROS rows through local business logic.

Rails may include a plain-text preview for small text/CSV files when it is cheap and helpful, but that preview is supporting context only. The raw source file remains the evidence the model reasons over.

### Source Understanding Artifact

The first model pass should produce a DB-backed source understanding artifact. This is the agent's interpretation of the uploaded event, not a deterministic parser output. It should be stored so later turns can reuse, inspect, and debug it.

```json
{
  "source_title": "Shared MOS_Millar Event - Run of Show.csv",
  "source_kind": "prior_event_ros",
  "overall_read": "Entertainment-heavy multi-day private event with Friday production setup and Saturday guest-facing program.",
  "inferred_days": [
    {
      "source_label": "Friday, June 13",
      "role": "day_before_event",
      "confidence": "high",
      "notes": "Contains one production line-check item."
    },
    {
      "source_label": "Saturday, June 14",
      "role": "main_event_day",
      "confidence": "high",
      "notes": "Contains crew calls, sound checks, HMU, guest arrivals, food and beverage service, performances, and departures."
    }
  ],
  "reusable_patterns": [
    "crew call",
    "sound check blocks",
    "hair and makeup appointments",
    "family ready and photos",
    "guest arrivals",
    "cocktail hour",
    "guest transitions",
    "food and beverage service",
    "late-night service",
    "guest departures"
  ],
  "source_specific_details": [
    {
      "detail": "Millar",
      "recommended_action": "remove_or_replace",
      "reason": "Source client name."
    },
    {
      "detail": "Portugal. The Man",
      "recommended_action": "convert_to_placeholder",
      "reason": "Source-specific headliner."
    }
  ],
  "uncertainties": [
    {
      "key": "ceremony_missing",
      "question_candidate": "The source lacks a ceremony anchor. Should I add ceremony/reception placeholders or only adapt the source rows?"
    }
  ]
}
```

### Draft ROS Scratchpad

After source understanding and Q&A, the agent should create a draft ROS scratchpad. This is a model-generated staging area, not live calendar data. The planner can refine it in turns before the final change plan is produced.

The scratchpad should include:

- Draft days and their target date mapping.
- Draft items with title, timing, duration, notes, location, vendor/staff placeholders, tags, confidence, and source references where available.
- Scrubbed source-specific details.
- Open assumptions.
- Items that need planner review.
- Change notes from each refinement turn.

The scratchpad can be overwritten or versioned per turn. The final apply step should use a structured change plan generated from the latest approved scratchpad, not the scratchpad directly.

## Real Source Sample Notes

The attached Millar source CSV has:

- One title row.
- Friday and Saturday date sections.
- Time range columns using start, "to", and end cells.
- Rich multiline descriptions in cells.
- Vendor, location, and PP staff columns.
- A production-heavy Saturday timeline with sound checks, HMU, guest arrivals, cocktails, transitions, performances, food/bar service, late-night service, and departures.
- Event-specific details such as client name, performers, custom menu/drink details, property-specific parking notes, green rooms, and named staff.

For this source, the likely recommended transformation is:

- Map source Saturday to the event wedding date.
- Map source Friday to the day before.
- Remove or generalize "Millar" and source-specific property details.
- Convert performers/vendors to placeholders unless the planner maps them.
- Preserve operational structure such as crew calls, sound checks, HMU, family ready, photos, arrivals, cocktails, transitions, performances, food/bar service, late-night, and departures.
- Add missing conventional wedding anchors only when the planner agrees, because the source is not a conventional ceremony-forward ROS.

## Agent Output Modes

### Source Understanding Output

Returned after the initial high-reasoning document read. This output can be followed by questions or a draft.

```json
{
  "state": "source_understood",
  "summary": "Short explanation of the source event.",
  "source_understanding": {},
  "recommended_next_state": "needs_input",
  "risk_notes": []
}
```

### Needs Input Output

Returned when the agent cannot safely produce a good plan without planner guidance.

```json
{
  "state": "needs_input",
  "summary": "Short explanation of what the agent understood.",
  "questions": [],
  "assumptions": [],
  "source_observations": [],
  "risk_notes": []
}
```

### Ready For Review Output

Returned when the agent has enough information to propose final app changes.

```json
{
  "state": "ready_for_review",
  "summary": "Short explanation of the proposed ROS update.",
  "assumptions": [],
  "operations": [],
  "warnings": [],
  "review_highlights": []
}
```

### Draft Scratchpad Output

Returned when the agent is creating or refining the staged ROS before final approval.

```json
{
  "state": "draft_ready",
  "summary": "Short explanation of the draft ROS.",
  "draft_ros": {},
  "assumptions": [],
  "review_notes": [],
  "suggested_next_questions": []
}
```

## ROS Change Plan

The agent should output a structured change plan. Rails validates the plan and converts it into a preview.

Supported operation types:

- `create_item`
- `update_item`
- `delete_item`
- `reorder_items`
- `create_tag`
- `assign_tags`
- `remove_tags`
- `set_item_team_members`
- `set_item_vendor`
- `set_item_location`
- `shift_absolute_times`
- `set_relative_timing`
- `create_view`
- `update_view`

Each operation should include:

- Operation ID.
- Operation type.
- Human-readable summary.
- Risk level: `low`, `medium`, or `high`.
- Target item reference when applicable.
- Source evidence references, such as file name and source row.
- Proposed attributes.
- Reasoning summary.

Destructive operations and large edits should be marked high risk and require explicit approval in the preview.

## Validation

Rails validates the agent plan before the planner can approve it.

Validation should check:

- The task belongs to the event being edited.
- Current user has planner/admin permission.
- Item IDs exist and belong to the event calendar.
- Referenced tags exist or are planned for creation.
- Relative anchors exist or are planned for creation.
- Relative timing does not create circular dependencies.
- Dates are valid in the calendar timezone.
- Durations are non-negative.
- Deletes are allowed only when the task is modifying an existing ROS.
- Large destructive batches are highlighted.
- Plan operations do not attempt to edit fields outside the allowed ROS surface.
- Event creation is not included.

Validation output should include blocking errors and non-blocking warnings.

## Preview And Approval

The preview should show:

- Count of creates, updates, deletes, tag changes, time changes, relative timing changes, and view changes.
- Timeline preview grouped by day.
- Before/after rows for changed existing items.
- Rows to be created.
- Rows to be deleted.
- Source evidence for each group where available.
- Assumptions and unanswered optional questions.
- High-risk operations requiring explicit acknowledgement.

Approval should record:

- Approving user.
- Approved timestamp.
- The exact plan version approved.
- Any high-risk acknowledgement state.

Applying should be transactional. If any operation fails, the task should fail without partially applying changes.

## Data Model Concept

The feature should introduce task history and trace tables. Exact column names can be refined during implementation, but the conceptual records are:

- `agent_tasks`: one workflow instance scoped to an event.
- `agent_task_artifacts`: raw source files and model-generated source understanding references.
- `agent_task_question_batches`: questions and answers for planning mode.
- `agent_task_events`: append-only task history for status transitions, agent responses, validation, previews, approval, apply results, and errors.
- `agent_task_llm_calls`: API request/response snapshots, response IDs, model, purpose, timings, usage, error details, and optional OpenAI trace metadata.

The task itself should also store the latest source understanding JSON, latest draft ROS scratchpad JSON, latest final plan JSON, validation JSON, preview JSON, and usage summary JSON. Source understanding and scratchpad records are allowed to be imperfect and model-authored. Final change plans must pass Rails validation before they can be approved.

This should stay separate from the existing `Approval` model. Existing approvals are business/client artifacts. Agent approvals are operational safety gates.

## OpenAI Integration

Use the Responses API from Rails for the first implementation. The Rails app should own workflow state, schemas, trace snapshots, validation, and write application. The OpenAI Agents SDK can be revisited later if a Python or TypeScript sidecar becomes worthwhile.

Recommended first-version approach:

- Use the official OpenAI Ruby SDK.
- Use `gpt-5.5` for source understanding, question generation, first drafts, major refinement turns, and final plan generation.
- Use cheaper models only for later, non-critical summaries or mechanical helper tasks.
- Use structured outputs for source understanding, draft ROS scratchpads, question batches, and final change plans.
- Use background jobs for slow work.
- Store OpenAI response IDs, request/response snapshots, usage metadata, and timings for every API call.
- Use file and image inputs for document understanding by default, including CSV/spreadsheet-like inputs.

### OpenAI Traces Dashboard

OpenAI's Traces dashboard is built into the Agents SDK tracing path. The first Rails implementation should not adopt a Python or TypeScript Agents SDK sidecar solely for dashboard traces. Instead, it should implement durable local tracing immediately through `agent_task_llm_calls` and task events. If later the team wants OpenAI-hosted traces, revisit either a small Agents SDK service or a supported tracing integration. That should be an explicit architecture decision, not a prerequisite for version 1.

## Tool Boundary

The agent should have access to high-level read and planning tools, not direct write tools.

Read/planning tools:

- `read_event_context`
- `read_current_ros`
- `read_ros_defaults`
- `attach_source_documents`
- `create_source_understanding`
- `update_draft_ros_scratchpad`
- `validate_question_batch`
- `validate_ros_change_plan`
- `preview_ros_change_plan`

Write/apply tool:

- `apply_approved_ros_change_plan`

The apply tool should be callable only by Rails after planner approval, not by the model during planning.

## Safety Model

- No writes during analysis, Q&A, or planning.
- Planner approval required for all create/update/delete/apply operations.
- High-risk operations require explicit acknowledgement.
- Task plan version must match the approved version at apply time.
- Application runs in a database transaction.
- Failures record a task event and leave existing ROS unchanged.
- Source-specific removals should be visible in the preview, not silently discarded.

## Tracing And Observability

Track:

- Model and reasoning setting.
- Response IDs.
- Provider request ID if available.
- Prompt version and schema version.
- LLM call purpose: source understanding, Q&A, draft, refinement, final plan, summary, or retry.
- Source artifact IDs.
- Input document IDs and OpenAI file IDs where available.
- Request payload snapshot with secrets redacted.
- Response payload snapshot, including structured output.
- Token usage and approximate cost.
- Time spent uploading files, understanding source docs, asking questions, drafting, refining, planning, validating, previewing, and applying.
- Number of questions asked.
- Number of operations proposed and applied.
- Validation failures.
- Planner answer overrides.
- Apply failures.
- Retry count and retry reasons.

Local trace snapshots are required in version 1. OpenAI-hosted trace dashboard support is optional and should not block the Rails-first implementation.

## Success Metrics

- Planner can give the provided sample CSV directly to the model and receive a reviewable ROS draft and final plan for an existing event.
- Planner can answer a Q&A batch and receive a revised plan.
- Planner can refine the draft scratchpad over multiple turns.
- Planner can preview changes before approval.
- No ROS writes occur before approval.
- The final applied ROS uses existing `CalendarItem`, tags, views, and scheduler behavior.
- Task history and LLM call snapshots explain how the agent moved from prompt to source understanding to questions to draft to plan to applied changes.

## Rollout Phases

### Phase 1: Internal Planner Prototype

- Existing-event flow only.
- Raw source document input to `gpt-5.5`.
- Model-generated source understanding.
- Draft ROS scratchpad.
- Q&A batch.
- Plan preview.
- Apply approved creates and updates.
- Task history and local API trace snapshots.

### Phase 2: Broader Source Support

- Stronger PDF/image/XLSX prompting and source evidence display.
- Stronger source confidence warnings from the model.
- More plan operations.

### Phase 3: Advanced Editing

- Existing ROS cleanup.
- Bulk analysis and cleanup.
- Per-operation accept/reject.
- More nuanced duplicate detection.

### Phase 4: New Event Bootstrapper

- Separate agentic flow that creates or prepares a new event.
- Hands off to the ROS agent after the event exists.
