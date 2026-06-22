# ROS Agent Execution Progress

Started: 2026-06-22
Branch: `codex/agentic-features`

## Current Status

- Overall: in progress
- Migration status: completed locally by maintainer; test DB prepared
- Test status: model, apply service, stubbed OpenAI/runner, and UI controller tests passed
- Live OpenAI smoke status: not run; budget is one tiny smoke call after stubbed tests pass
- OpenAI key decision: reuse existing `OPENAI_API_KEY`
- Production/live database: do not run migrations from Codex

## Subagent Assignments

- DB/Models worker: blocked on sandboxed Postgres after red tests; main agent completed migration/model implementation
- OpenAI/Runner worker: blocked on sandboxed Postgres after red tests; main agent completed implementation
- ROS Apply worker: blocked on sandboxed Postgres after red tests; main agent completed services
- UI worker: blocked on sandboxed Postgres after red tests; main agent completed controller/view implementation

## Checklist

- [ ] Create progress tracker and commit it
- [x] Add agent task migrations
- [x] Add agent task models and fixtures
- [x] Add model tests
- [x] Add OpenAI SDK wrapper
- [x] Add source document upload/input handling
- [x] Add structured output schemas
- [x] Add local trace recorder
- [x] Add runner and background job
- [x] Add ROS change plan validator
- [x] Add ROS preview builder
- [x] Add transactional ROS applier
- [x] Add event-scoped routes and controller
- [x] Add Agent Assist CTA to ROS top bar
- [x] Add task form, Q&A, draft, preview, approval, and apply views
- [x] Add minimal Stimulus behavior
- [x] Add controller tests
- [ ] Add end-to-end stubbed test
- [x] Ask maintainer to run migrations
- [x] Verify schema and tests after migration output
- [ ] Run one tiny live OpenAI smoke call

## Notes

- The feature works inside an existing event only.
- Source documents are model evidence, not locally parsed ROS rows.
- Q&A and draft refinement never authorize writes.
- Planner approval is required before every create/update/delete apply.
- Local trace snapshots are required for every OpenAI call.
