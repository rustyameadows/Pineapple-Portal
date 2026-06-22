# ROS Agent Execution Progress

Started: 2026-06-22
Branch: `codex/agentic-features`

## Current Status

- Overall: in progress
- Migration status: not created yet
- Test status: not run yet
- Live OpenAI smoke status: not run; budget is one tiny smoke call after stubbed tests pass
- OpenAI key decision: reuse existing `OPENAI_API_KEY`
- Production/live database: do not run migrations from Codex

## Subagent Assignments

- DB/Models worker: in progress (`gpt-5.4`, high reasoning)
- OpenAI/Runner worker: in progress (`gpt-5.4`, high reasoning)
- ROS Apply worker: pending
- UI worker: pending

## Checklist

- [ ] Create progress tracker and commit it
- [ ] Add agent task migrations
- [ ] Add agent task models and fixtures
- [ ] Add model tests
- [ ] Add OpenAI SDK wrapper
- [ ] Add source document upload/input handling
- [ ] Add structured output schemas
- [ ] Add local trace recorder
- [ ] Add runner and background job
- [ ] Add ROS change plan validator
- [ ] Add ROS preview builder
- [ ] Add transactional ROS applier
- [ ] Add event-scoped routes and controller
- [ ] Add Agent Assist CTA to ROS top bar
- [ ] Add task form, Q&A, draft, preview, approval, and apply views
- [ ] Add minimal Stimulus behavior
- [ ] Add controller and end-to-end stubbed tests
- [ ] Ask maintainer to run migrations
- [ ] Verify schema and tests after migration output
- [ ] Run one tiny live OpenAI smoke call

## Notes

- The feature works inside an existing event only.
- Source documents are model evidence, not locally parsed ROS rows.
- Q&A and draft refinement never authorize writes.
- Planner approval is required before every create/update/delete apply.
- Local trace snapshots are required for every OpenAI call.
